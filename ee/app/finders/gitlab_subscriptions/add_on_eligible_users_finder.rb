# frozen_string_literal: true

module GitlabSubscriptions
  class AddOnEligibleUsersFinder
    include Gitlab::Utils::StrongMemoize

    def initialize(group, add_on_type:, search_term: nil)
      @group = group
      @add_on_type = add_on_type
      @search_term = search_term
    end

    def execute
      return User.none unless add_on_type == :code_suggestions && group.root?

      members = Member
                  .with(group_namespaces_cte.to_arel) # rubocop:disable CodeReuse/ActiveRecord
                  .with(base_ancestors_cte.to_arel) # rubocop:disable CodeReuse/ActiveRecord
                  .with(namespace_ban_cte.to_arel) # rubocop:disable CodeReuse/ActiveRecord
                  .from_union(member_relations)

      users = User
                .id_in(members.select(:user_id))
                .allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/426357")

      users = users.search(search_term) if search_term

      users
    end

    private

    attr_reader :group, :add_on_type, :search_term

    def member_relations
      [
        members_from_descendant_projects.select(:user_id),
        members_from_groups.select(:user_id)
      ]
    end

    def members_from_descendant_projects
      ProjectMember
        .left_join_users
        .merge(User.with_state(:active).without_bots)
        .without_invites_and_requests
        .where.not(user_id: namespace_ban_user_ids) # rubocop:disable CodeReuse/ActiveRecord
        .with_source_id(Project.in_namespace(our_group_namespaces))
    end

    # rubocop:disable CodeReuse/ActiveRecord
    def members_from_groups
      all_groups_sql = <<~SQL
        "members"."source_id" IN (
          SELECT unnest("base_ancestors_cte"."traversal_ids") FROM base_ancestors_cte
          UNION
          SELECT id FROM our_group_namespaces
        )
      SQL

      GroupMember
        .left_join_users
        .merge(User.with_state(:active).without_bots)
        .without_invites_and_requests
        .where.not(user_id: namespace_ban_user_ids)
        .where(all_groups_sql)
    end
    # rubocop:enable CodeReuse/ActiveRecord

    def group_namespaces_cte
      query = @group.self_and_descendant_ids

      Gitlab::SQL::CTE.new(:our_group_namespaces, query, materialized: false)
    end
    strong_memoize_attr :group_namespaces_cte

    def our_group_namespaces
      Namespace
        .from(group_namespaces_cte.table) # rubocop:disable CodeReuse/ActiveRecord
        .select(:id)
    end

    def base_ancestors_cte
      group_links_sql = <<~SQL
        "namespaces"."id" IN (
          SELECT
            "group_group_links"."shared_with_group_id"
          FROM
            group_group_links
          WHERE
            "group_group_links"."shared_group_id" IN (SELECT id FROM our_group_namespaces )
          UNION
          SELECT
            "project_group_links"."group_id"
          FROM
            project_group_links
          WHERE
            "project_group_links"."project_id" IN (
              SELECT id FROM projects WHERE "projects"."namespace_id" IN (
                SELECT id FROM "our_group_namespaces"
              )
            )
        )
      SQL

      query = Group.select('namespaces.traversal_ids').where(Arel.sql(group_links_sql)) # rubocop:disable CodeReuse/ActiveRecord

      Gitlab::SQL::CTE.new(:base_ancestors_cte, query, materialized: false)
    end
    strong_memoize_attr :base_ancestors_cte

    def namespace_ban_cte
      query = ::Namespaces::NamespaceBan.where(namespace: group).select(:user_id) # rubocop:disable CodeReuse/ActiveRecord

      Gitlab::SQL::CTE.new(:our_namespace_bans, query, materialized: false)
    end
    strong_memoize_attr :namespace_ban_cte

    def namespace_ban_user_ids
      ::Namespaces::NamespaceBan.from(namespace_ban_cte.table).select(:user_id) # rubocop:disable CodeReuse/ActiveRecord
    end
  end
end
