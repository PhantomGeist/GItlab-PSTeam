# frozen_string_literal: true

module API
  module Admin
    module Search
      class Zoekt < ::API::Base
        MAX_RESULTS = 20

        feature_category :global_search
        urgency :low

        helpers do
          def ensure_zoekt_indexing_enabled!
            return if Feature.enabled?(:index_code_with_zoekt)

            error!(
              'index_code_with_zoekt feature flag is not enabled', 400
            )
          end
        end

        before do
          authenticated_as_admin!
        end

        namespace 'admin' do
          resources 'zoekt/projects/:project_id/index' do
            desc 'Triggers indexing for the specified project' do
              success ::API::Entities::Search::Zoekt::ProjectIndexSuccess
              failure [
                { code: 401, message: '401 Unauthorized' },
                { code: 403, message: '403 Forbidden' },
                { code: 404, message: '404 Not found' }
              ]
            end
            params do
              requires :project_id,
                type: Integer,
                desc: 'The id of the project you want to index'
            end
            put do
              ensure_zoekt_indexing_enabled!
              project = Project.find(params[:project_id])

              job_id = project.repository.async_update_zoekt_index

              present({ job_id: job_id }, with: ::API::Entities::Search::Zoekt::ProjectIndexSuccess)
            end
          end

          resources 'zoekt/shards' do
            desc 'Get all the Zoekt shards' do
              success ::API::Entities::Search::Zoekt::Shard
              failure [
                { code: 401, message: '401 Unauthorized' },
                { code: 403, message: '403 Forbidden' },
                { code: 404, message: '404 Not found' }
              ]
            end
            get do
              present ::Search::Zoekt::Node.all, with: ::API::Entities::Search::Zoekt::Shard
            end

            resources ':shard_id/indexed_namespaces' do
              desc 'Get all the indexed namespaces for this shard' do
                success ::API::Entities::Search::Zoekt::IndexedNamespace
                failure [
                  { code: 401, message: '401 Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 404, message: '404 Not found' }
                ]
              end
              params do
                requires :shard_id,
                  type: Integer,
                  desc: 'The id of the Zoekt::Shard'
              end
              get do
                node = ::Search::Zoekt::Node.find(params[:shard_id])
                indexed_namespaces = node.indexed_namespaces.recent.with_limit(MAX_RESULTS)

                present indexed_namespaces, with: ::API::Entities::Search::Zoekt::IndexedNamespace
              end

              resources ':namespace_id' do
                desc 'Add a namespace to a node for Zoekt indexing' do
                  success ::API::Entities::Search::Zoekt::IndexedNamespace
                  failure [
                    { code: 401, message: '401 Unauthorized' },
                    { code: 403, message: '403 Forbidden' },
                    { code: 404, message: '404 Not found' }
                  ]
                end
                params do
                  requires :shard_id,
                    type: Integer,
                    desc: 'The id of the Search::Zoekt::Node'
                  requires :namespace_id,
                    type: Integer,
                    desc: 'The id of the namespace you want to index in this node'
                end
                put do
                  ensure_zoekt_indexing_enabled!
                  node = ::Search::Zoekt::Node.find(params[:shard_id])
                  namespace = Namespace.find(params[:namespace_id])

                  indexed_namespace = ::Zoekt::IndexedNamespace
                    .find_or_create_for_node_and_namespace!(node: node, namespace: namespace)
                  present indexed_namespace, with: ::API::Entities::Search::Zoekt::IndexedNamespace
                end

                desc 'Remove a namespace from a node for Zoekt indexing' do
                  failure [
                    { code: 401, message: '401 Unauthorized' },
                    { code: 403, message: '403 Forbidden' },
                    { code: 404, message: '404 Not found' }
                  ]
                end
                params do
                  requires :shard_id,
                    type: Integer,
                    desc: 'The id of the Search::Zoekt::Node'
                  requires :namespace_id,
                    type: Integer,
                    desc: 'The id of the namespace you want to index in this node'
                end
                delete do
                  node = ::Search::Zoekt::Node.find(params[:shard_id])
                  namespace = Namespace.find(params[:namespace_id])

                  indexed_namespace = ::Zoekt::IndexedNamespace
                    .for_node_and_namespace!(node: node, namespace: namespace)
                  indexed_namespace.destroy!

                  ''
                end
              end
            end
          end
        end
      end
    end
  end
end
