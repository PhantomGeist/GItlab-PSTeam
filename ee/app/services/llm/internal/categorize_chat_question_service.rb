# frozen_string_literal: true

module Llm
  module Internal
    class CategorizeChatQuestionService < BaseService
      extend ::Gitlab::Utils::Override

      private

      def perform
        schedule_completion_worker
      end

      def ai_action
        :categorize_question
      end
    end
  end
end
