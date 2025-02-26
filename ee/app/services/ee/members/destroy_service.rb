# frozen_string_literal: true

module EE
  module Members
    module DestroyService
      extend ::Gitlab::Utils::Override

      def after_execute(member:, skip_saml_identity: false)
        super

        if system_event? && removed_due_to_expiry?(member)
          log_audit_event(member: member, author: nil, action: :expired)
        else
          log_audit_event(member: member, author: current_user, action: :destroy)
        end

        cleanup_group_identity(member) unless skip_saml_identity
        cleanup_group_deletion_schedule(member) if member.source.is_a?(Group)
        cleanup_oncall_rotations(member)
        cleanup_escalation_rules(member) if member.user
      end

      private

      def removed_due_to_expiry?(member)
        member.expired?
      end

      def system_event?
        current_user.blank?
      end

      def log_audit_event(member:, author:, action:)
        audit_context = {
          name: 'member_destroyed',
          scope: member.source,
          target: member.user || ::Gitlab::Audit::NullTarget.new,
          target_details: member.user ? member.user.name : 'Deleted User',
          additional_details: {
            remove: "user_access",
            member_id: member.id
          }
        }

        case action
        when :destroy
          audit_context.update(
            author: author,
            message: 'Membership destroyed'
          )
        when :expired
          audit_context.update(
            author: ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)'),
            message: "Membership expired on #{member.expires_at}"
          )
          audit_context[:additional_details].update(
            system_event: true,
            reason: "access expired on #{member.expires_at}"
          )
        end

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def cleanup_group_identity(member)
        saml_provider = member.source.try(:saml_provider)

        return unless saml_provider

        saml_provider.identities.for_user(member.user).delete_all
      end

      def cleanup_group_deletion_schedule(member)
        deletion_schedule = member.source&.deletion_schedule

        return unless deletion_schedule

        deletion_schedule.destroy if deletion_schedule.deleting_user == member.user
      end

      def cleanup_oncall_rotations(member)
        user = member.user

        return unless user

        user_rotations = ::IncidentManagement::MemberOncallRotationsFinder.new(member).execute

        return unless user_rotations.present?

        ::IncidentManagement::OncallRotations::RemoveParticipantsService.new(
          user_rotations,
          user
        ).execute
      end

      def cleanup_escalation_rules(member)
        rules = ::IncidentManagement::EscalationRulesFinder.new(member: member, include_removed: true).execute

        ::IncidentManagement::EscalationRules::DestroyService.new(escalation_rules: rules, user: member.user).execute
      end

      override :enqueue_cleanup_jobs_once_per_heirarchy
      def enqueue_cleanup_jobs_once_per_heirarchy(member, unassign_issuables)
        super

        enqueue_cleanup_add_on_seat_assignments(member)
        enqueue_cleanup_group_protected_branch_rules(member)
      end

      override :destroy_data_related_to_member
      def destroy_data_related_to_member(member, skip_subresources, skip_saml_identity)
        super

        return unless member.user
        return unless member.source.licensed_feature_available?(:ai_features)

        ::User.clear_group_with_ai_available_cache(member.user.id)
      end

      def enqueue_cleanup_add_on_seat_assignments(member)
        namespace = member.source.root_ancestor

        return unless ::Feature.enabled?(:hamilton_seat_management, namespace)

        member.run_after_commit_or_now do
          GitlabSubscriptions::AddOnPurchases::CleanupUserAddOnAssignmentWorker.perform_async(
            namespace.id,
            member.user_id
          )
        end
      end

      def enqueue_cleanup_group_protected_branch_rules(member)
        return unless member.source.is_a?(Group)

        member.run_after_commit_or_now do
          ::MembersDestroyer::CleanUpGroupProtectedBranchRulesWorker.perform_async(member.source.id, member.user_id)
        end
      end
    end
  end
end
