# frozen_string_literal: true

module Resolvers
  module GitlabSubscriptions
    class AddOnEligibleUsersResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      argument :search,
        type: GraphQL::Types::String,
        required: false,
        description: 'Search the user list.'

      argument :add_on_type,
        type: Types::GitlabSubscriptions::AddOnTypeEnum,
        required: true,
        description: 'Type of add on to filter the eligible users by.'

      type ::Types::GitlabSubscriptions::AddOnUserType.connection_type,
        null: true

      alias_method :namespace, :object

      def resolve(add_on_type:, search: nil)
        authorize!(namespace)

        return [] unless Feature.enabled?(:hamilton_seat_management, namespace)

        ::GitlabSubscriptions::AddOnEligibleUsersFinder.new(
          namespace,
          add_on_type: add_on_type,
          search_term: search
        ).execute
      end

      private

      def authorize!(namespace)
        raise_resource_not_available_error! unless Ability.allowed?(current_user, :admin_add_on_purchase, namespace)

        return if namespace.root?

        raise_resource_not_available_error!("Add on eligible users can only be queried on a root namespace")
      end
    end
  end
end
