# frozen_string_literal: true

module Llm
  module Embedding
    module GitlabDocumentation
      module EmbeddingsWorkerContext
        extend ActiveSupport::Concern

        MODEL = ::Embedding::Vertex::GitlabDocumentation
        DOC_DIRECTORY = 'doc'
        BATCH_SIZE = 50
        EMBEDDINGS_PER_SECOND = 7
        RATE_LIMITER_PERIOD = 10.seconds
        EMBEDDINGS_PER_RATE_LIMITER_PERIOD = (RATE_LIMITER_PERIOD * EMBEDDINGS_PER_SECOND).to_i
        FEATURE_NAME = :ai_vertex_embeddings

        def embedding_delay(key:, start_in: RATE_LIMITER_PERIOD, rate_per_second: EMBEDDINGS_PER_SECOND, ttl: 2.hours)
          ::Gitlab::Redis::SharedState.with do |redis|
            redis.multi do |multi|
              multi.set(key.to_s, start_in + 1, nx: true, ex: ttl)
              multi.incrbyfloat(key.to_s, 1.to_f / rate_per_second)
            end.last
          end
        end
      end
    end
  end
end
