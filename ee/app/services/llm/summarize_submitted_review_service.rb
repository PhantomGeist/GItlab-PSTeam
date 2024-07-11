# frozen_string_literal: true

module Llm
  class SummarizeSubmittedReviewService < ::Llm::BaseService
    private

    def ai_action
      :summarize_submitted_review
    end

    def perform
      schedule_completion_worker
    end

    def valid?
      super &&
        resource.to_ability_name == "merge_request" &&
        Ability.allowed?(user, :summarize_submitted_review, resource)
    end
  end
end
