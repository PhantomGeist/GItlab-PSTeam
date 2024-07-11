# frozen_string_literal: true

module EE
  module MemberPresenter
    extend ::Gitlab::Utils::Override
    extend ::Gitlab::Utils::DelegatorOverride

    def can_update?
      super || can_override?
    end

    override :can_override?
    def can_override?
      can?(current_user, override_member_permission, member)
    end

    delegator_override :human_access
    def human_access
      return member_role.name if member_role

      super
    end

    delegator_override :valid_member_roles
    def valid_member_roles
      return super unless ::Feature.enabled?(:custom_roles_in_members_page, group)

      root_group = member.source&.root_ancestor
      member_roles = root_group.member_roles

      if member.highest_group_member
        member_roles = member_roles.select do |role|
          role.base_access_level >= member.highest_group_member.access_level
        end
      end

      member_roles.map do |member_role|
        {
          base_access_level: member_role.base_access_level,
          member_role_id: member_role.id,
          name: member_role.name
        }
      end
    end

    def custom_permissions
      return super unless member_role

      member_role.enabled_permissions.each.map do |permission|
        { key: permission, name: permission.to_s.humanize }
      end
    end

    private

    def override_member_permission
      raise NotImplementedError
    end
  end
end
