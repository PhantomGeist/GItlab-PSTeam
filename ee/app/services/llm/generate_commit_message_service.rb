# frozen_string_literal: true

module Llm
  class GenerateCommitMessageService < BaseService
    def valid?
      super &&
        Feature.enabled?(:generate_commit_message_flag, user) &&
        resource.resource_parent.root_ancestor.licensed_feature_available?(:generate_commit_message) &&
        Gitlab::Llm::StageCheck.available?(resource.resource_parent, :generate_commit_message)
    end

    private

    def ai_action
      :generate_commit_message
    end

    def perform
      schedule_completion_worker
    end
  end
end
