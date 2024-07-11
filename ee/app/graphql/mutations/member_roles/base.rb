# frozen_string_literal: true

module Mutations
  module MemberRoles
    class Base < ::Mutations::BaseMutation
      field :member_role, ::Types::MemberRoles::MemberRoleType,
        description: 'Updated member role.', null: true

      argument :description,
        GraphQL::Types::String,
        required: false,
        description: 'Description of the member role.'
      argument :name,
        GraphQL::Types::String,
        required: false,
        description: 'Name of the member role.'
    end
  end
end
