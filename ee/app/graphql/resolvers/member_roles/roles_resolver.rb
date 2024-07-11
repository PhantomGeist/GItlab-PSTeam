# frozen_string_literal: true

module Resolvers
  module MemberRoles
    class RolesResolver < BaseResolver
      type Types::MemberRoles::MemberRoleType, null: true

      def resolve
        object.root_ancestor.member_roles
      end
    end
  end
end
