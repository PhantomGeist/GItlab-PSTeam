# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatMessage < AiMessage
      RESET_MESSAGE = '/reset'

      def save!
        ChatStorage.new(user).add(self)
      end

      def conversation_reset?
        content == RESET_MESSAGE
      end
    end
  end
end
