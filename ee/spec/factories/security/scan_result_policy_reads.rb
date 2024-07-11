# frozen_string_literal: true

FactoryBot.define do
  factory :scan_result_policy_read, class: 'Security::ScanResultPolicyRead' do
    security_orchestration_policy_configuration
    project

    orchestration_policy_idx { 0 }
    match_on_inclusion { true }
    sequence :rule_idx

    trait :blocking_protected_branches do
      project_approval_settings { { block_unprotecting_branches: true } }
    end

    trait :prevent_approval_by_author do
      project_approval_settings { { prevent_approval_by_author: true } }
    end

    trait :prevent_approval_by_commit_author do
      project_approval_settings { { prevent_approval_by_commit_author: true } }
    end

    trait :require_password_to_approve do
      project_approval_settings { { require_password_to_approve: true } }
    end

    trait :remove_approvals_with_new_commit do
      project_approval_settings { { remove_approvals_with_new_commit: true } }
    end
  end
end
