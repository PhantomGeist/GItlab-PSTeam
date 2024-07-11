# frozen_string_literal: true

module Preloaders
  class UserMemberRolesInProjectsPreloader
    def initialize(projects:, user:)
      @projects = if projects.is_a?(Array)
                    Project.where(id: projects)
                  else
                    # Push projects base query in to a sub-select to avoid
                    # table name clashes. Performs better than aliasing.
                    Project.where(id: projects.reselect(:id))
                  end

      @user = user
    end

    def execute
      ::Gitlab::SafeRequestLoader.execute(
        resource_key: resource_key,
        resource_ids: projects.map(&:id)
      ) do
        abilities_for_user_grouped_by_project
      end
    end

    private

    def abilities_for_user_grouped_by_project
      sql_values_array = projects.filter_map do |project|
        next unless project.custom_roles_enabled?

        [project.id, Arel.sql("ARRAY[#{project.namespace.traversal_ids.join(',')}]::integer[]")]
      end

      return {} if sql_values_array.empty?

      value_list = Arel::Nodes::ValuesList.new(sql_values_array)

      permissions = MemberRole::ALL_CUSTOMIZABLE_PROJECT_PERMISSIONS
      permission_select = permissions.map { |p| "bool_or(custom_permissions.#{p}) AS #{p}" }.join(', ')
      permission_condition = permissions.map { |p| "member_roles.#{p} = true" }.join(' OR ')
      result_default = permissions.map { |p| "false AS #{p}" }.join(', ')

      sql = <<~SQL
      SELECT project_ids.project_id, #{permission_select}
        FROM (#{value_list.to_sql}) AS project_ids (project_id, namespace_ids),
        LATERAL (
          (
           #{Member.select(permissions.join(', '))
              .left_outer_joins(:member_role)
              .where("members.source_type = 'Project' AND members.source_id = project_ids.project_id")
              .with_user(user)
              .where(permission_condition)
              .limit(1).to_sql}
          ) UNION ALL
          (
            #{Member.select(permissions.join(', '))
              .left_outer_joins(:member_role)
              .where("members.source_type = 'Namespace' AND members.source_id IN (SELECT UNNEST(project_ids.namespace_ids) as ids)")
              .with_user(user)
              .where(permission_condition)
              .limit(1).to_sql}
          ) UNION ALL
          (
            SELECT #{result_default}
          )
          LIMIT 1
        ) AS custom_permissions
        GROUP BY project_ids.project_id;
      SQL

      grouped_by_project = ApplicationRecord.connection.execute(sql).to_a.group_by do |h|
        h['project_id']
      end

      grouped_by_project.transform_values do |value|
        permissions.filter_map do |permission|
          permission if value.find { |custom_role| custom_role[permission.to_s] == true }
        end
      end
    end

    def resource_key
      "member_roles_in_projects:user:#{user.id}"
    end

    attr_reader :projects, :user
  end
end
