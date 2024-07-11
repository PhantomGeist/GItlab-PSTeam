# frozen_string_literal: true

module Search
  module Zoekt
    class DeleteProjectWorker
      include ApplicationWorker
      include Gitlab::ExclusiveLeaseHelpers

      TIMEOUT = 1.minute
      MAX_JOBS_PER_HOUR = 3600

      data_consistency :delayed

      feature_category :global_search
      urgency :throttled
      idempotent!
      pause_control :zoekt

      def perform(root_namespace_id, project_id, node_id = nil)
        return unless ::Feature.enabled?(:index_code_with_zoekt)
        return unless ::License.feature_available?(:zoekt_code_search)

        node_id ||= ::Search::Zoekt::Node.for_namespace(root_namespace_id: root_namespace_id)&.id

        return false unless node_id

        in_lock("#{self.class.name}/#{project_id}", ttl: TIMEOUT, retries: 0) do
          ::Gitlab::Search::Zoekt::Client.delete(node_id: node_id, project_id: project_id)
        end
      end
    end
  end
end
