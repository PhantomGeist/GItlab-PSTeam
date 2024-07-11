# frozen_string_literal: true

module EE
  module IssuePolicy
    extend ActiveSupport::Concern

    prepended do
      with_scope :subject
      condition(:ai_available) do
        ::Feature.enabled?(:openai_experimentation) || ::Feature.enabled?(:ai_global_switch, type: :ops)
      end

      with_scope :subject
      condition(:summarize_notes_enabled) do
        (::Feature.enabled?(:openai_experimentation) || ::Feature.enabled?(:ai_global_switch, type: :ops)) &&
          subject_container.licensed_feature_available?(:summarize_notes) &&
          ::Gitlab::Llm::StageCheck.available?(subject_container, :summarize_notes)
      end

      with_scope :subject
      condition(:generate_description_enabled) do
        (::Feature.enabled?(:openai_experimentation) || ::Feature.enabled?(:ai_global_switch, type: :ops)) &&
          subject_container.licensed_feature_available?(:generate_description) &&
          ::Gitlab::Llm::StageCheck.available?(subject_container, :generate_description)
      end

      rule { can_be_promoted_to_epic }.policy do
        enable :promote_to_epic
      end

      rule do
        ai_available & summarize_notes_enabled & is_project_member & can?(:read_issue)
      end.enable :summarize_notes

      rule do
        ai_available & generate_description_enabled & is_project_member & can?(:read_issue)
      end.enable :generate_description
    end
  end
end
