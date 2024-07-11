# frozen_string_literal: true

module Llm
  class GenerateTestFileService < BaseService
    def valid?
      super &&
        Feature.enabled?(:generate_test_file_flag, user) &&
        resource.resource_parent.root_ancestor.licensed_feature_available?(:generate_test_file) &&
        Gitlab::Llm::StageCheck.available?(resource.resource_parent, :generate_test_file)
    end

    private

    def ai_action
      :generate_test_file
    end

    def perform
      schedule_completion_worker
    end
  end
end
