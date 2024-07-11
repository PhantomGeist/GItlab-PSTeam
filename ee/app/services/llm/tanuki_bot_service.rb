# frozen_string_literal: true

module Llm
  class TanukiBotService < BaseService
    def valid?
      super && Gitlab::Llm::TanukiBot.enabled_for?(user: user)
    end

    private

    def ai_action
      :tanuki_bot
    end

    def perform
      schedule_completion_worker
    end

    def content(_action_name)
      options[:question]
    end
  end
end
