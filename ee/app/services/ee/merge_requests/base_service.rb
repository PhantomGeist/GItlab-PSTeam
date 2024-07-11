# frozen_string_literal: true

module EE
  module MergeRequests
    module BaseService
      extend ::Gitlab::Utils::Override

      private

      attr_accessor :blocking_merge_requests_params, :suggested_reviewer_ids

      override :execute_external_hooks
      def execute_external_hooks(merge_request, merge_data)
        merge_request.project.execute_external_compliance_hooks(merge_data)
      end

      override :filter_params
      def filter_params(merge_request)
        unless current_user.can?(:update_approvers, merge_request)
          params.delete(:approvals_before_merge)
          params.delete(:approver_ids)
          params.delete(:approver_group_ids)
        end

        self.params = ApprovalRules::ParamsFilteringService.new(merge_request, current_user, params).execute

        self.blocking_merge_requests_params =
          ::MergeRequests::UpdateBlocksService.extract_params!(params)

        super
      end

      override :filter_suggested_reviewers
      def filter_suggested_reviewers
        suggested_reviewer_ids_from_params = params.delete(:suggested_reviewer_ids)
        return if suggested_reviewer_ids_from_params.blank?

        self.suggested_reviewer_ids = suggested_reviewer_ids_from_params & params[:reviewer_ids]
      end

      def reset_approvals?(merge_request, _newrev)
        delete_approvals?(merge_request) || merge_request.target_project.project_setting.selective_code_owner_removals
      end

      def delete_approvals?(merge_request)
        merge_request.target_project.reset_approvals_on_push ||
          merge_request.policy_approval_settings.fetch(:remove_approvals_with_new_commit, false)
      end

      def delete_approvals(merge_request, patch_id_sha: nil)
        approvals = merge_request.approvals
        approvals = filter_approvals(approvals, patch_id_sha) if patch_id_sha.present?
        approvals.delete_all

        # In case there is still a temporary flag on the MR
        merge_request.approval_state.expire_unapproved_key!

        trigger_merge_request_merge_status_updated(merge_request)
        trigger_merge_request_approval_state_updated(merge_request)
      end

      def filter_approvals(approvals, patch_id_sha)
        approvals.with_invalid_patch_id_sha(patch_id_sha)
      end

      def all_approvers(merge_request)
        merge_request.overall_approvers(exclude_code_owners: true)
      end

      override :capture_suggested_reviewers_accepted
      def capture_suggested_reviewers_accepted(merge_request)
        return if suggested_reviewer_ids.blank?

        ::MergeRequests::CaptureSuggestedReviewersAcceptedWorker
          .perform_async(merge_request.id, suggested_reviewer_ids)
      end

      def log_audit_event(merge_request, event_name, message)
        audit_context = {
          name: event_name,
          author: current_user,
          scope: merge_request.target_project,
          target: merge_request,
          message: message,
          target_details:
            { iid: merge_request.iid,
              id: merge_request.id,
              source_branch: merge_request.source_branch,
              target_branch: merge_request.target_branch }
        }

        if event_name == 'merge_request_merged_by_project_bot'
          audit_context[:target_details][:merge_commit_sha] = merge_request.merge_commit_sha
        end

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
