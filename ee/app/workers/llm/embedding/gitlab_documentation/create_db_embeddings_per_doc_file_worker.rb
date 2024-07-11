# frozen_string_literal: true

module Llm
  module Embedding
    module GitlabDocumentation
      class CreateDbEmbeddingsPerDocFileWorker
        include ApplicationWorker
        include Gitlab::ExclusiveLeaseHelpers
        include EmbeddingsWorkerContext

        idempotent!
        data_consistency :always # rubocop: disable SidekiqLoadBalancing/WorkerDataConsistency
        feature_category :duo_chat
        urgency :throttled
        sidekiq_options retry: 5
        loggable_arguments 0

        def perform(filename, update_version)
          return unless Gitlab::Saas.feature_available?(FEATURE_NAME)
          return unless Feature.enabled?(:openai_experimentation) || Feature.enabled?(:ai_global_switch, type: :ops)
          return unless ::License.feature_available?(:ai_chat) # license check
          # if this job gets rescheduled for a late enough run it may so happen the file is not there anymore
          return unless File.exist?(filename)

          @update_version = update_version
          @filename = filename
          content = File.read(filename)
          source = filename.gsub(Rails.root.to_s, '')

          # This worker needs to be idempotent, so that in case of a failure, if this worker is re-run, we make
          # sure we do not create duplicate entries for the same file. For that reason, we cleanup any records
          # for the passed in filename and given update_version.
          file_embeddings = MODEL.select(:id).for_source(source).for_version(update_version)
          file_embeddings.each_batch(of: BATCH_SIZE) { |batch| batch.delete_all } # rubocop:disable Style/SymbolProc

          items = ::Gitlab::Llm::Embeddings::Utils::DocsContentParser.parse_and_split(content, source, DOC_DIRECTORY)

          # By default VertexAI has 600 requests per minute(i.e. 10 req/sec) quota for embeddings endpoint based on
          # https://cloud.google.com/vertex-ai/docs/quotas#request_quotas,
          # so let's schedule roughly ~7 jobs per second for now. That is what items.each_slice(EMBEDDINGS_PER_SECOND)
          # does here.
          #
          # We should consider filling a quota increase request when we know more about the overall embeddings usage,
          # but we still want these requests throttled.
          items.each_slice(EMBEDDINGS_PER_SECOND) do |batch|
            records = batch.map { |item| build_embedding_record(item) }
            bulk_create_records(records)
          end
        end

        private

        attr_reader :update_version, :filename

        def bulk_create_records(records)
          embedding_ids = MODEL.bulk_insert!(records, returns: :ids)
          logger.info(
            structured_payload(
              message: 'Creating DB embedding records',
              filename: filename,
              new_embeddings: embedding_ids,
              new_version: update_version
            )
          )

          embedding_ids.each do |record_id|
            delay = embedding_delay(key: :enqueue_set_embeddings_on_db_record, start_in: 3.minutes, ttl: 3.minutes)
            SetEmbeddingsOnTheRecordWorker.perform_in(delay, record_id, update_version)
          end
        end

        def build_embedding_record(item)
          current_time = Time.current

          ::Embedding::Vertex::GitlabDocumentation.new(
            created_at: current_time,
            updated_at: current_time,
            embedding: item[:embedding],
            metadata: item[:metadata],
            content: item[:content],
            url: item[:url],
            version: update_version
          )
        end
      end
    end
  end
end
