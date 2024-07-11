# frozen_string_literal: true

module ApprovalRules
  class FinalizeService
    attr_reader :merge_request

    def initialize(merge_request)
      @merge_request = merge_request
    end

    def execute
      return unless merge_request.merged?

      # fails ee/spec/services/approval_rules/finalize_service_spec.rb
      cross_join_issue = "https://gitlab.com/gitlab-org/gitlab/-/issues/417459"
      ::Gitlab::Database.allow_cross_joins_across_databases(url: cross_join_issue) do
        ApplicationRecord.transaction do
          if merge_request.approval_rules.regular.exists?
            merge_group_members_into_users
          else
            copy_project_approval_rules
          end

          merge_request.approval_rules.each(&:sync_approved_approvers)
        end
      end
    end

    private

    def merge_group_members_into_users
      merge_request.approval_rules.each do |rule|
        rule.users |= rule.group_users
      end
    end

    # This freezes the approval state at the time of merge. By copying
    # project-level rules as merge request-level rules, the approval
    # state will be unaffected if project rules get changed or removed.
    def copy_project_approval_rules
      rules_by_name = merge_request.approval_rules.index_by(&:name)

      ff_enabled = Feature.enabled?(:copy_additional_properties_approval_rules, merge_request.project)
      attributes_to_slice = %w[approvals_required name]
      attributes_to_slice.append(*%w[rule_type report_type]) if ff_enabled

      merge_request.target_project.approval_rules.each do |project_rule|
        users = project_rule.approvers
        groups = project_rule.groups.public_or_visible_to_user(merge_request.author)
        name = project_rule.name

        next unless name.present?

        rule = rules_by_name[name]

        # If the rule already exists, we just skip this one without
        # updating the current state. If the approval rules were changed
        # after merging a merge request, syncing the data might make it
        # appear as though this merge request hadn't been approved.
        next if rule

        new_rule = merge_request.approval_rules.new(
          project_rule.attributes.slice(*attributes_to_slice).merge(users: users, groups: groups)
        )

        # If we fail to save with the new attributes, then let's default back to the simplified ones
        if new_rule.valid?
          new_rule.save!
        else
          Gitlab::AppLogger.debug(
            "Failed to persist approval rule: #{new_rule.errors.full_messages}. Defaulting to original rules"
          )
          merge_request.approval_rules.create!(
            project_rule.attributes.slice(*%w[approvals_required name]).merge(users: users, groups: groups)
          )
        end
      end
    end
  end
end
