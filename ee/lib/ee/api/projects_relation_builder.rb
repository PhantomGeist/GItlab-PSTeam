# frozen_string_literal: true

module EE
  module API
    module ProjectsRelationBuilder
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :preload_member_roles
        def preload_member_roles(projects, user)
          ::Preloaders::UserMemberRolesInProjectsPreloader.new(
            projects: projects,
            user: user
          ).execute
        end
      end
    end
  end
end
