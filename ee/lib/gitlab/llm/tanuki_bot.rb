# frozen_string_literal: true

module Gitlab
  module Llm
    class TanukiBot
      include ::Gitlab::Loggable

      REQUEST_TIMEOUT = 30
      CONTENT_ID_FIELD = 'ATTRS'
      CONTENT_ID_REGEX = /CNT-IDX-(?<id>\d+)/
      RECORD_LIMIT = 4
      MODEL = 'claude-instant-1.1'

      def self.enabled_for?(user:)
        return false unless user
        return false unless ::License.feature_available?(:ai_tanuki_bot)
        return false unless Feature.enabled?(:openai_experimentation) || Feature.enabled?(:ai_global_switch, type: :ops)
        return false unless ai_feature_enabled?(user)

        true
      end

      def self.ai_feature_enabled?(user)
        return true unless ::Gitlab.com?

        user.any_group_with_ai_available?
      end

      def self.show_breadcrumbs_entry_point_for?(user:)
        return false unless Feature.enabled?(:tanuki_bot_breadcrumbs_entry_point, user)

        enabled_for?(user: user)
      end

      def initialize(current_user:, question:, logger: nil, tracking_context: {})
        @current_user = current_user
        @question = question
        @logger = logger || Gitlab::Llm::Logger.build
        @correlation_id = Labkit::Correlation::CorrelationId.current_id
        @tracking_context = tracking_context
      end

      def execute(&block)
        return empty_response unless question.present?
        return empty_response unless self.class.enabled_for?(user: current_user)

        unless ::Embedding::Vertex::GitlabDocumentation.any?
          logger.debug(message: "Need to query docs but no embeddings are found")
          return empty_response
        end

        embedding = embedding_for_question(question)
        return empty_response if embedding.nil?

        search_documents = get_nearest_neighbors(embedding)
        return empty_response if search_documents.empty?

        get_completions(search_documents, &block)
      end

      # Note: a Rake task is using this method to extract embeddings for a test fixture.
      def embedding_for_question(question)
        embeddings_result = vertex_client.text_embeddings(content: question)
        embeddings_result['predictions'].first['embeddings']['values']
      end

      # Note: a Rake task is using this method to extract embeddings for a test fixture.
      def get_nearest_neighbors(embedding)
        ::Embedding::Vertex::GitlabDocumentation.current.neighbor_for(
          embedding,
          limit: RECORD_LIMIT
        ).map do |item|
          item.metadata['source_url'] = item.url

          {
            id: item.id,
            content: item.content,
            metadata: item.metadata
          }
        end
      end

      private

      attr_reader :current_user, :question, :logger, :correlation_id, :tracking_context

      def vertex_client
        @vertex_client ||= ::Gitlab::Llm::VertexAi::Client.new(current_user, tracking_context: tracking_context)
      end

      def anthropic_client
        @anthropic_client ||= ::Gitlab::Llm::Anthropic::Client.new(current_user, tracking_context: tracking_context)
      end

      def get_completions(search_documents)
        final_prompt = Gitlab::Llm::Anthropic::Templates::TanukiBot
          .final_prompt(question: question, documents: search_documents)

        final_prompt_result = anthropic_client.stream(
          prompt: final_prompt[:prompt],
          options: {
            model: "claude-instant-1.1"
          }
        ) do |data|
          logger.info(message: "Streaming error", error: data&.dig("error")) if data&.dig("error")

          yield data&.dig("completion").to_s if block_given?
        end

        logger.debug(message: "Got Final Result", prompt: final_prompt[:prompt], response: final_prompt_result)

        Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot.new(
          { completion: final_prompt_result }.to_json, current_user
        )
      end

      def empty_response
        Gitlab::Llm::ResponseModifiers::EmptyResponseModifier.new(
          _("I'm sorry, I was not able to find any documentation to answer your question.")
        )
      end
    end
  end
end
