# frozen_string_literal: true

module Llm
  class FillInMergeRequestTemplateService < BaseService
    extend ::Gitlab::Utils::Override

    override :valid
    def valid?
      super &&
        resource.is_a?(Project) &&
        Ability.allowed?(user, :fill_in_merge_request_template, resource)
    end

    private

    def ai_action
      :fill_in_merge_request_template
    end

    def perform
      schedule_completion_worker
    end
  end
end
