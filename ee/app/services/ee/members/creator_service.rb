# frozen_string_literal: true

module EE
  module Members
    module CreatorService
      extend ::Gitlab::Utils::Override
      extend ActiveSupport::Concern

      private

      class_methods do
        extend ::Gitlab::Utils::Override

        def parsed_args(args)
          super.merge(member_role_id: args[:member_role_id])
        end
      end

      override :member_attributes
      def member_attributes
        attributes = super.merge(ldap: ldap)

        return attributes unless ::Feature.enabled?(:invitations_member_role_id, source)

        top_level_group = source.root_ancestor

        return attributes unless top_level_group.custom_roles_enabled?

        attributes.merge(member_role_id: args[:member_role_id])
      end

      override :after_commit_tasks
      def after_commit_tasks
        super

        finish_onboarding_user
      end

      override :commit_member
      def commit_member
        if security_bot_and_member_of_other_project?
          member.errors.add(:base, _('security policy bot users cannot be added to other projects'))
        else
          super
        end
      end

      def finish_onboarding_user
        return unless ::Onboarding.user_onboarding_in_progress?(member.user)
        return unless finished_welcome_step?

        member.user.update(onboarding_step_url: nil, onboarding_in_progress: false)
      end

      def finished_welcome_step?
        member.user.role?
      end

      def security_bot_and_member_of_other_project?
        return false unless member.user&.security_policy_bot?

        ::Member.exists?(user_id: member.user.id) # rubocop:disable CodeReuse/ActiveRecord
      end
    end
  end
end
