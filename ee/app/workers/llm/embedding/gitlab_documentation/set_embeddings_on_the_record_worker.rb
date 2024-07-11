# frozen_string_literal: true

module Llm
  module Embedding
    module GitlabDocumentation
      class SetEmbeddingsOnTheRecordWorker
        include ApplicationWorker
        include Gitlab::ExclusiveLeaseHelpers
        include EmbeddingsWorkerContext

        TRACKING_CONTEXT = { action: 'documentation_embedding' }.freeze

        idempotent!
        deduplicate :until_executing
        worker_has_external_dependencies!
        data_consistency :delayed
        feature_category :duo_chat
        urgency :throttled
        sidekiq_options retry: 5

        def perform(id, update_version)
          return unless Gitlab::Saas.feature_available?(FEATURE_NAME)
          return unless Feature.enabled?(:openai_experimentation) || Feature.enabled?(:ai_global_switch, type: :ops)
          return unless ::License.feature_available?(:ai_chat) # license check

          @update_version = update_version

          if ::Gitlab::ApplicationRateLimiter.throttled?(:vertex_embeddings_api, scope: nil)
            delay = embedding_delay(key: embedding_delay_key, start_in: 10.seconds)
            self.class.perform_in(delay, id, update_version)

            return
          end

          record = MODEL.find_by_id(id)
          return unless record

          client = ::Gitlab::Llm::VertexAi::Client.new(nil, tracking_context: TRACKING_CONTEXT)
          result = client.text_embeddings(content: record.content)

          unless result.success? && result.has_key?('predictions')
            raise StandardError, result.dig('error', 'message') || "Could not generate embedding: '#{result}'"
          end

          embedding = result['predictions'].first['embeddings']['values']
          record.update!(embedding: embedding)

          replace_old_embeddings(record)
          cleanup_embedding_delay unless MODEL.nil_embeddings_for_version(update_version).exists?
        end

        private

        attr_reader :update_version

        def replace_old_embeddings(record)
          source = record.metadata["source"]

          in_lock("#{self.class.name.underscore}/#{source}", ttl: 1.minute, sleep_sec: 1) do
            new_embeddings = MODEL.for_source(source).for_version(update_version)

            break unless new_embeddings.exists?
            break if MODEL.for_source(source).nil_embeddings_for_version(update_version).exists?

            old_embeddings = MODEL.for_version(update_version).invert_where.for_source(source)
            old_embeddings.each_batch(of: 100) { |batch| batch.delete_all } # rubocop:disable Style/SymbolProc

            new_embeddings.each_batch(of: 100) { |batch| batch.update_all(version: MODEL.current_version) } # rubocop:disable Style/SymbolProc
          end
        end

        def cleanup_embedding_delay
          ::Gitlab::Redis::SharedState.with do |redis|
            redis.del(embedding_delay_key)
          end
        end

        def embedding_delay_key
          "re_enqueue_set_embeddings_on_db_record"
        end
      end
    end
  end
end
