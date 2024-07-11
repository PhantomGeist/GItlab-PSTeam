# frozen_string_literal: true

module EE
  module MergeRequests
    module UpdateService
      extend ::Gitlab::Utils::Override

      private

      override :general_fallback
      def general_fallback(merge_request)
        reset_approval_rules(merge_request) if params.delete(:reset_approval_rules_to_defaults)

        merge_request = super(merge_request)

        merge_request.reset_approval_cache!

        return merge_request if update_task_event?

        ::MergeRequests::UpdateBlocksService
          .new(merge_request, current_user, blocking_merge_requests_params)
          .execute

        merge_request
      end

      override :after_update
      def after_update(merge_request, old_associations)
        super

        merge_request.run_after_commit do
          ::MergeRequests::SyncCodeOwnerApprovalRulesWorker.perform_async(merge_request.id)
        end
      end

      override :delete_approvals_on_target_branch_change
      def delete_approvals_on_target_branch_change(merge_request)
        delete_approvals(merge_request) if reset_approvals?(merge_request, nil)
        sync_any_merge_request_approval_rules(merge_request)
      end

      def reset_approval_rules(merge_request)
        return unless merge_request.project.can_override_approvers?

        merge_request.approval_rules.regular_or_any_approver.delete_all
      end

      def sync_any_merge_request_approval_rules(merge_request)
        return if ::Feature.disabled?(:scan_result_any_merge_request, merge_request.project)
        return unless merge_request.approval_rules.any_merge_request.any?

        ::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker.perform_async(merge_request.id)
      end
    end
  end
end
