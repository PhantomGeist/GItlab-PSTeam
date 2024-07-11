# frozen_string_literal: true

module Gitlab
  module Llm
    class StageCheck
      EXPERIMENTAL_FEATURES = [
        :ai_analyze_ci_job_failure,
        :summarize_notes,
        :summarize_my_mr_code_review,
        :explain_code,
        :generate_description,
        :generate_test_file,
        :summarize_diff,
        :explain_vulnerability,
        :generate_commit_message,
        :chat,
        :fill_in_merge_request_template,
        :summarize_submitted_review
      ].freeze
      BETA_FEATURES = [].freeze
      THIRD_PARTY_FEATURES = EXPERIMENTAL_FEATURES + BETA_FEATURES

      class << self
        def available?(group, feature)
          available_on_experimental_stage?(group, feature) &&
            available_on_beta_stage?(group, feature) &&
            available_as_third_party_feature?(group, feature)
        end

        private

        def available_on_experimental_stage?(group, feature)
          return true unless EXPERIMENTAL_FEATURES.include?(feature)

          group&.root_ancestor&.experiment_features_enabled
        end

        # There is no beta setting yet.
        # https://gitlab.com/gitlab-org/gitlab/-/issues/409929
        def available_on_beta_stage?(group, feature)
          return true unless BETA_FEATURES.include?(feature)

          group&.root_ancestor&.experiment_features_enabled
        end

        def available_as_third_party_feature?(group, feature)
          return true unless THIRD_PARTY_FEATURES.include?(feature)

          group&.root_ancestor&.third_party_ai_features_enabled
        end
      end
    end
  end
end
