# frozen_string_literal: true

module EE
  module RendersProjectsList
    extend ::Gitlab::Utils::Override

    override :preload_member_roles
    def preload_member_roles(projects)
      ::Preloaders::UserMemberRolesInProjectsPreloader.new(
        projects: projects,
        user: current_user
      ).execute
    end
  end
end
