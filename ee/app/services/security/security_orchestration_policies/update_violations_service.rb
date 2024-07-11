# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class UpdateViolationsService
      attr_reader :merge_request,
        :violated_policy_ids,
        :unviolated_policy_ids

      def initialize(merge_request)
        @merge_request = merge_request
        @violated_policy_ids = Set.new
        @unviolated_policy_ids = Set.new
      end

      def add(violated_ids, unviolated_ids)
        violated_policy_ids.merge(violated_ids)
        unviolated_policy_ids.merge(unviolated_ids)
      end

      def execute
        return [violated_policy_ids.clear, unviolated_policy_ids.clear] unless Feature.enabled?(
          :scan_result_any_merge_request, merge_request.project)

        Security::ScanResultPolicyViolation.transaction do
          delete_violations if unviolated_policy_ids.any?
          create_violations if violated_policy_ids.any?
        end

        [violated_policy_ids.clear, unviolated_policy_ids.clear]
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def delete_violations
        Security::ScanResultPolicyViolation
          .where(merge_request_id: merge_request.id, scan_result_policy_id: unviolated_policy_ids)
          .each_batch(order_hint: :updated_at) { |batch| batch.delete_all } # rubocop: disable Style/SymbolProc
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def create_violations
        attrs = violated_policy_ids.map do |id|
          { scan_result_policy_id: id, merge_request_id: merge_request.id, project_id: merge_request.project_id }
        end

        Security::ScanResultPolicyViolation.insert_all(attrs) if attrs.any?
      end
    end
  end
end
