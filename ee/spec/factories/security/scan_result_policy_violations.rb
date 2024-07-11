# frozen_string_literal: true

FactoryBot.define do
  factory :scan_result_policy_violation, class: 'Security::ScanResultPolicyViolation' do
    project
    merge_request
    scan_result_policy_read
  end
end
