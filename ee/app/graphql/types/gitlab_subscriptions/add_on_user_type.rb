# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    class AddOnUserType < UserType
      graphql_name 'AddOnUser'
      description 'A user with add-on data'

      authorize :read_user

      field :add_on_assignments,
        type: ::Types::GitlabSubscriptions::UserAddOnAssignmentType.connection_type,
        resolver: ::Resolvers::GitlabSubscriptions::UserAddOnAssignmentsResolver,
        description: 'Add-on purchase assignments for the user.',
        alpha: { milestone: '16.4' }

      field :last_activity_on,
        type: Types::DateType,
        null: true,
        description: 'Date the user last performed any actions.'
      field :last_login_at,
        type: Types::TimeType,
        null: true,
        method: :current_sign_in_at,
        description: 'Timestamp of the last sign in.'
    end
  end
end
