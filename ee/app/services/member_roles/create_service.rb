# frozen_string_literal: true

module MemberRoles
  class CreateService < BaseService
    def execute
      return authorized_error unless allowed?

      unless group.root?
        return ::ServiceResponse.error(message: _('Creation of member role is allowed only for root groups'))
      end

      create_member_role
    end

    private

    def create_member_role
      member_role = MemberRole.new(params.merge(namespace: group))

      if member_role.save
        ::ServiceResponse.success(payload: { member_role: member_role })
      else
        ::ServiceResponse.error(message: member_role.errors.full_messages.join(', '))
      end
    end
  end
end
