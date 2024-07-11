# frozen_string_literal: true

module Ci
  module Subscriptions
    class ProjectPolicy < BasePolicy
      condition(:admin_downstream_project) do
        can?(:admin_project, @subject.downstream_project)
      end

      condition(:admin_access_to_both_projects) do
        can?(:admin_project, @subject.downstream_project)
      end

      condition(:developer_access_to_downstream_project) do
        can?(:developer_access, @subject.upstream_project)
      end

      rule { admin_access_to_both_projects & developer_access_to_downstream_project }.policy do
        enable :read_project_subscription
      end

      rule { admin_downstream_project }.policy { enable :delete_project_subscription }
    end
  end
end
