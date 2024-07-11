# frozen_string_literal: true

module Projects
  class AllBranchesRule < BranchRule
    include Projects::CustomBranchRule

    attr_reader :project

    def initialize(project)
      @project = project
    end

    def name
      s_('All branches')
    end

    def matching_branches_count
      project.repository.branch_count
    end

    def approval_project_rules
      project.approval_rules.for_all_branches
    end

    def external_status_checks
      project.external_status_checks.for_all_branches
    end
  end
end
