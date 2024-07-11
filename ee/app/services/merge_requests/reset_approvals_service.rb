# frozen_string_literal: true

module MergeRequests
  class ResetApprovalsService < ::MergeRequests::BaseService
    def execute(ref, newrev, skip_reset_checks: false)
      reset_approvals_for_merge_requests(ref, newrev, skip_reset_checks)
    end

    private

    # Note: Closed merge requests also need approvals reset.
    def reset_approvals_for_merge_requests(ref, newrev, skip_reset_checks = false)
      branch_name = ::Gitlab::Git.ref_name(ref)
      merge_requests = merge_requests_for(branch_name, mr_states: [:opened, :closed])

      merge_requests.each do |merge_request|
        if Feature.enabled?(:reset_approvals_patch_id, merge_request.project)
          mr_patch_id_sha = merge_request.current_patch_id_sha
        end

        if skip_reset_checks
          # Delete approvals immediately, with no additional checks or side-effects
          #
          delete_approvals(merge_request, patch_id_sha: mr_patch_id_sha)
        else
          reset_approvals(merge_request, newrev, patch_id_sha: mr_patch_id_sha)
        end
      end
    end

    def reset_approvals?(merge_request, newrev)
      super && merge_request.rebase_commit_sha != newrev
    end

    def reset_approvals(merge_request, newrev = nil, patch_id_sha: nil)
      return unless reset_approvals?(merge_request, newrev)

      if delete_approvals?(merge_request)
        delete_approvals(merge_request, patch_id_sha: patch_id_sha)
      elsif merge_request.target_project.project_setting.selective_code_owner_removals
        delete_code_owner_approvals(merge_request, patch_id_sha: patch_id_sha)
      end
    end

    def delete_code_owner_approvals(merge_request, patch_id_sha: nil)
      return if merge_request.approvals.empty?

      code_owner_rules = approved_code_owner_rules(merge_request)
      return if code_owner_rules.empty?

      rule_names = ::Gitlab::CodeOwners.entries_since_merge_request_commit(merge_request).map(&:pattern)
      match_ids = code_owner_rules.flat_map do |rule|
        next unless rule_names.include?(rule.name)

        rule.approved_approvers.map(&:id)
      end.compact

      # In case there is still a temporary flag on the MR
      merge_request.approval_state.expire_unapproved_key!

      approvals = merge_request.approvals.where(user_id: match_ids) # rubocop:disable CodeReuse/ActiveRecord
      approvals = filter_approvals(approvals, patch_id_sha) if patch_id_sha.present?
      approvals.delete_all
      trigger_merge_request_merge_status_updated(merge_request)
      trigger_merge_request_approval_state_updated(merge_request)
    end

    def approved_code_owner_rules(merge_request)
      merge_request.wrapped_approval_rules.select { |rule| rule.code_owner? && rule.approved_approvers.any? }
    end
  end
end
