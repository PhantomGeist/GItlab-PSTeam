# frozen_string_literal: true

module Gitlab
  module Search
    module Zoekt
      class Client # rubocop:disable Search/NamespacedClass
        include Gitlab::Utils::StrongMemoize
        INDEXING_TIMEOUT_S = 30.minutes.to_i

        class << self
          def instance
            @instance ||= new
          end

          delegate :search, :index, :delete, :truncate, to: :instance
        end

        def search(query, num:, project_ids:, node_id:)
          start = Time.current

          payload = {
            Q: query,
            Opts: {
              TotalMaxMatchCount: num,
              NumContextLines: 1
            }
          }

          # Safety net because Zoekt will match all projects if you provide
          # an empty array.
          raise 'Not possible to search without at least one project specified' if project_ids.blank?
          raise 'Global search is not supported' if project_ids == :any

          payload[:RepoIDs] = project_ids
          path = '/api/search'
          target_node = node(node_id)
          raise 'Node can not be found' unless target_node

          response = post(
            join_url(target_node.search_base_url, path),
            payload,
            allow_local_requests: true,
            basic_auth: basic_auth_params
          )

          unless response.success?
            logger.error(message: 'Zoekt search failed', status: response.code, response: response.body)
          end

          parse_response(response)
        ensure
          add_request_details(start_time: start, path: path, body: payload)
        end

        def index(project, node_id)
          response = zoekt_indexer_post('/indexer/index', indexing_payload(project), node_id)

          raise "Request failed with: #{response.inspect}" unless response.success?

          parsed_response = parse_response(response)
          raise parsed_response['Error'] if parsed_response['Error']

          response
        end

        def delete(node_id:, project_id:)
          target_node = node(node_id)
          raise 'Node can not be found' unless target_node

          response = delete_request(join_url(target_node.index_base_url, "/indexer/index/#{project_id}"))

          raise "Request failed with: #{response.inspect}" unless response.success?

          parsed_response = parse_response(response)
          raise parsed_response['Error'] if parsed_response['Error']

          response
        end

        def truncate
          ::Search::Zoekt::Node.find_each { |node| post(join_url(node.index_base_url, '/indexer/truncate')) }
        end

        private

        def post(url, payload = {}, **options)
          defaults = {
            headers: { "Content-Type" => "application/json" },
            body: payload.to_json,
            allow_local_requests: true,
            basic_auth: basic_auth_params
          }
          ::Gitlab::HTTP.post(
            url,
            defaults.merge(options)
          )
        end

        def delete_request(url, **options)
          defaults = {
            allow_local_requests: true,
            basic_auth: basic_auth_params
          }
          ::Gitlab::HTTP.delete(
            url,
            defaults.merge(options)
          )
        end

        def zoekt_indexer_post(path, payload, node_id)
          target_node = node(node_id)
          raise 'Node can not be found' unless target_node

          post(
            join_url(target_node.index_base_url, path),
            payload,
            timeout: INDEXING_TIMEOUT_S
          )
        end

        def basic_auth_params
          @basic_auth_params ||= {
            username: username,
            password: password
          }.compact
        end

        def indexing_payload(project)
          repository_storage = project.repository_storage
          connection_info = Gitlab::GitalyClient.connection_data(repository_storage)
          repository_path = "#{project.repository.disk_path}.git"
          address = connection_info['address']

          # This code is needed to support relative unix: connection strings. For example, specs
          if address.match?(%r{\Aunix:[^/.]})
            path = address.split('unix:').last
            address = "unix:#{Rails.root.join(path)}"
          end

          {
            GitalyConnectionInfo: {
              Address: address,
              Token: connection_info['token'],
              Storage: repository_storage,
              Path: repository_path
            },
            RepoId: project.id,
            FileSizeLimit: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes,
            Timeout: "#{INDEXING_TIMEOUT_S}s"
          }
        end

        def node(node_id)
          ::Search::Zoekt::Node.find_by_id(node_id)
        end

        def join_url(base_url, path)
          # We can't use URI.join because it doesn't work properly with something like
          # URI.join('http://example.com/api', 'index') => #<URI::HTTP http://example.com/index>
          url = [base_url, path].join('/')
          url.gsub(%r{(?<!:)/+}, '/') # Remove duplicate slashes
        end

        def parse_response(response)
          ::Gitlab::Json.parse(response.body).with_indifferent_access
        end

        def add_request_details(start_time:, path:, body:)
          return unless ::Gitlab::SafeRequestStore.active?

          duration = (Time.current - start_time)

          ::Gitlab::Instrumentation::Zoekt.increment_request_count
          ::Gitlab::Instrumentation::Zoekt.add_duration(duration)

          ::Gitlab::Instrumentation::Zoekt.add_call_details(
            duration: duration,
            method: 'POST',
            path: path,
            body: body
          )
        end

        def username
          @username ||= File.exist?(username_file) ? File.read(username_file).chomp : nil
        end

        def password
          @password ||= File.exist?(password_file) ? File.read(password_file).chomp : nil
        end

        def username_file
          Gitlab.config.zoekt.username_file
        end

        def password_file
          Gitlab.config.zoekt.password_file
        end

        def logger
          @logger ||= ::Zoekt::Logger.build
        end
      end
    end
  end
end
