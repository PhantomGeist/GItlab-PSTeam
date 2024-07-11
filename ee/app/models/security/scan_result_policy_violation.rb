# frozen_string_literal: true

module Security
  class ScanResultPolicyViolation < ApplicationRecord
    include EachBatch

    belongs_to :project, inverse_of: :scan_result_policy_violations
    belongs_to :scan_result_policy_read,
      class_name: 'Security::ScanResultPolicyRead',
      foreign_key: 'scan_result_policy_id',
      inverse_of: :violations

    belongs_to :merge_request, inverse_of: :scan_result_policy_violations

    validates :scan_result_policy_id, uniqueness: { scope: %i[merge_request_id] }

    scope :including_scan_result_policy_reads, -> { includes(:scan_result_policy_read) }
  end
end
