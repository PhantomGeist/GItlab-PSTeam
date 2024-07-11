# frozen_string_literal: true

module Llm
  module Embedding
    module GitlabDocumentation
      class CleanupPreviousVersionsRecordsWorker
        include ApplicationWorker
        include CronjobQueue # rubocop:disable Scalability/CronWorkerContext
        include EmbeddingsWorkerContext

        idempotent!
        data_consistency :always # rubocop: disable SidekiqLoadBalancing/WorkerDataConsistency
        feature_category :duo_chat
        urgency :throttled

        BATCH_SIZE = 1000
        TIME_LIMIT = 3.minutes

        def perform
          return unless Gitlab::Saas.feature_available?(FEATURE_NAME)
          return unless Feature.enabled?(:openai_experimentation) || Feature.enabled?(:ai_global_switch, type: :ops)
          return unless ::License.feature_available?(:ai_chat) # license check

          ::Embedding::Vertex::GitlabDocumentation.previous.limit(BATCH_SIZE).delete_all

          return unless ::Embedding::Vertex::GitlabDocumentation.previous.exists?

          Llm::Embedding::GitlabDocumentation::CleanupPreviousVersionsRecordsWorker.perform_in(10.seconds)
        end
      end
    end
  end
end
