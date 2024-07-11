# frozen_string_literal: true

module Llm
  class SummarizeMergeRequestService < ::Llm::BaseService
    private

    def ai_action
      :summarize_merge_request
    end

    def perform
      schedule_completion_worker
    end

    def valid?
      super &&
        resource.to_ability_name == "merge_request" &&
        Ability.allowed?(user, :summarize_merge_request, resource)
    end
  end
end
