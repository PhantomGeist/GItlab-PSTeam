# frozen_string_literal: true

module Types
  module MemberRoles
    class MemberRoleType < BaseObject
      graphql_name 'MemberRole'
      description 'Represents a member role'

      authorize :read_group_member

      field :id,
        ::Types::GlobalIDType[::MemberRole],
        null: false,
        description: 'ID of the member role.'

      field :name,
        GraphQL::Types::String,
        null: false,
        description: 'Name of the member role.'

      field :description,
        GraphQL::Types::String,
        null: true,
        description: 'Description of the member role.'

      field :admin_merge_request,
        GraphQL::Types::Boolean,
        null: true,
        alpha: { milestone: '16.5' },
        description: 'Permission to admin merge requests.'

      field :admin_vulnerability,
        GraphQL::Types::Boolean,
        null: true,
        alpha: { milestone: '16.5' },
        description: 'Permission to admin vulnerability.'

      field :admin_group_member,
        GraphQL::Types::Boolean,
        null: true,
        alpha: { milestone: '16.5' },
        description: 'Permission to admin group members.'

      field :manage_project_access_tokens,
        GraphQL::Types::Boolean,
        null: true,
        alpha: { milestone: '16.5' },
        description: 'Permission to admin project access tokens.'

      field :read_code,
        GraphQL::Types::Boolean,
        null: true,
        alpha: { milestone: '16.5' },
        description: 'Permission to read code.'

      field :read_dependency,
        GraphQL::Types::Boolean,
        null: true,
        alpha: { milestone: '16.5' },
        description: 'Permission to read dependency.'

      field :read_vulnerability,
        GraphQL::Types::Boolean,
        null: true,
        alpha: { milestone: '16.5' },
        description: 'Permission to read vulnerability.'

      field :base_access_level,
        Types::AccessLevelType,
        null: false,
        alpha: { milestone: '16.5' },
        description: 'Base access level for the custom role.'

      field :enabled_permissions,
        [Types::MemberRoles::PermissionsEnum],
        null: true,
        alpha: { milestone: '16.5' },
        description: 'Array of all permissions enabled for the custom role.'
    end
  end
end
