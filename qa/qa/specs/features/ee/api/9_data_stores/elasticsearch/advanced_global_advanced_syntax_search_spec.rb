# frozen_string_literal: true

require 'airborne'

module QA
  RSpec.describe 'Data Stores', product_group: :global_search do
    describe(
      'Elasticsearch advanced global search with advanced syntax',
      :orchestrated,
      :elasticsearch,
      except: :production
    ) do
      include_context 'advanced search active'

      let(:project_name_suffix) { SecureRandom.hex(8) }
      let(:api_client) { Runtime::API::Client.new(:gitlab) }

      let(:project) do
        create(:project,
          name: "es-adv-global-search-#{project_name_suffix}",
          description: "This is a unique project description #{project_name_suffix}")
      end

      before do
        create(:commit, project: project, actions: [
          { action: 'create', file_path: 'elasticsearch.rb', content: "elasticsearch: #{SecureRandom.hex(8)}" }
        ])
      end

      context 'when searching for projects using advanced syntax' do
        it(
          'searches in the project name',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348066'
        ) do
          expect_search_to_find_project("es-adv-*#{project_name_suffix}")
        end

        it(
          'searches in the project description',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348067'
        ) do
          expect_search_to_find_project("unique +#{project_name_suffix}")
        end
      end

      private

      def expect_search_to_find_project(search_term)
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          get(Runtime::Search.create_search_request(api_client, 'projects', search_term).url)
          aggregate_failures do
            expect_status(QA::Support::API::HTTP_STATUS_OK)
            expect(json_body).not_to be_empty
            expect(json_body[0][:name]).to eq(project.name)
          end
        end
      end
    end
  end
end
