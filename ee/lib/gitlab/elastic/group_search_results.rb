# frozen_string_literal: true

module Gitlab
  module Elastic
    # Always prefer to use the full class namespace when specifying a
    # superclass inside a module, because autoloading can occur in a
    # different order between execution environments.
    class GroupSearchResults < Gitlab::Elastic::SearchResults
      extend Gitlab::Utils::Override

      attr_reader :group, :default_project_filter, :filters

      # rubocop:disable Metrics/ParameterLists
      def initialize(current_user, query, limit_project_ids = nil, group:, public_and_internal_projects: false, default_project_filter: false, order_by: nil, sort: nil, filters: {})
        @group = group
        @default_project_filter = default_project_filter
        @filters = filters

        super(current_user, query, limit_project_ids, public_and_internal_projects: public_and_internal_projects, order_by: order_by, sort: sort, filters: filters)
      end
      # rubocop:enable Metrics/ParameterLists

      override :base_options
      def base_options
        super.merge(search_scope: 'group', group_ids: [group.id]) # group_ids to options for traversal_ids filtering
      end

      override :scope_options
      def scope_options(scope)
        # User uses group_id for namespace_query
        return super.except(:group_ids).merge(group_id: group.id) if scope == :users

        super
      end
    end
  end
end
