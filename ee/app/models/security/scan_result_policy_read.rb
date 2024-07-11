# frozen_string_literal: true

module Security
  class ScanResultPolicyRead < ApplicationRecord
    include EachBatch

    self.table_name = 'scan_result_policies'

    enum age_operator: { greater_than: 0, less_than: 1 }
    enum age_interval: { day: 0, week: 1, month: 2, year: 3 }
    enum commits: { any: 0, unsigned: 1 }, _prefix: true

    belongs_to :security_orchestration_policy_configuration, class_name: 'Security::OrchestrationPolicyConfiguration'
    belongs_to :project, optional: true
    has_many :software_license_policies
    has_many :approval_merge_request_rules, foreign_key: 'scan_result_policy_id', inverse_of: :scan_result_policy_read
    has_many :violations, foreign_key: 'scan_result_policy_id', class_name: 'Security::ScanResultPolicyViolation',
      inverse_of: :scan_result_policy_read

    validates :match_on_inclusion, inclusion: { in: [true, false], message: 'must be a boolean value' }
    validates :role_approvers, inclusion: { in: Gitlab::Access.all_values }
    validates :age_value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :vulnerability_attributes, json_schema: { filename: 'scan_result_policy_vulnerability_attributes' },
      allow_blank: true
    validates :rule_idx,
      uniqueness: { scope: %i[security_orchestration_policy_configuration_id project_id orchestration_policy_idx] },
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :project_approval_settings, json_schema: { filename: 'scan_result_policy_project_approval_settings' },
      allow_blank: true

    scope :targeting_commits, -> { where.not(commits: nil) }
    scope :including_approval_merge_request_rules, -> { includes(:approval_merge_request_rules) }

    def newly_detected?
      license_states.include?(ApprovalProjectRule::NEWLY_DETECTED)
    end

    def vulnerability_age
      return {} unless age_operator.present? && age_interval.present? && age_value.present?

      { operator: age_operator.to_sym, interval: age_interval.to_sym, value: age_value }
    end
  end
end
