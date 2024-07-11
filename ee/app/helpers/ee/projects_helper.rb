# frozen_string_literal: true

module EE
  module ProjectsHelper
    extend ::Gitlab::Utils::Override

    override :sidebar_operations_paths
    def sidebar_operations_paths
      super + %w[
        oncall_schedules
      ]
    end

    override :project_permissions_settings
    def project_permissions_settings(project)
      super.merge({
        requirementsAccessLevel: project.requirements_access_level,
        cveIdRequestEnabled: (project.public? && project.project_setting.cve_id_request_enabled?)
      })
    end

    override :project_permissions_panel_data
    def project_permissions_panel_data(project)
      super.merge({
        requirementsAvailable: project.feature_available?(:requirements),
        requestCveAvailable: ::Gitlab.com?,
        cveIdRequestHelpPath: help_page_path('user/application_security/cve_id_request')
      })
    end

    override :default_url_to_repo
    def default_url_to_repo(project = @project)
      case default_clone_protocol
      when 'krb5'
        project.kerberos_url_to_repo
      else
        super
      end
    end

    override :extra_default_clone_protocol
    def extra_default_clone_protocol
      if alternative_kerberos_url? && current_user
        "krb5"
      else
        super
      end
    end

    override :remove_project_message
    def remove_project_message(project)
      return super unless project.adjourned_deletion?

      date = permanent_deletion_date(Time.now.utc)
      _("Deleting a project places it into a read-only state until %{date}, at which point the project will be permanently deleted. Are you ABSOLUTELY sure?") %
        { date: date }
    end

    def approvals_app_data(project = @project)
      {
        project_id: project.id,
        can_edit: can_modify_approvers.to_s,
        can_modify_author_settings: can_modify_author_settings.to_s,
        can_modify_commiter_settings: can_modify_commiter_settings.to_s,
        project_path: expose_path(api_v4_projects_path(id: project.id)),
        approvals_path: expose_path(api_v4_projects_merge_request_approval_setting_path(id: project.id)),
        rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
        allow_multi_rule: project.multiple_approval_rules_available?.to_s,
        eligible_approvers_docs_path: help_page_path('user/project/merge_requests/approvals/rules', anchor: 'eligible-approvers'),
        security_configuration_path: project_security_configuration_path(project),
        coverage_check_help_page_path: help_page_path('ci/testing/code_coverage', anchor: 'coverage-check-approval-rule'),
        group_name: project.root_ancestor.name,
        full_path: project.full_path,
        new_policy_path: expose_path(new_project_security_policy_path(project))
      }
    end

    def status_checks_app_data(project)
      {
        data: {
          project_id: project.id,
          status_checks_path: expose_path(api_v4_projects_external_status_checks_path(id: project.id))
        }
      }
    end

    def can_modify_approvers(project = @project)
      can?(current_user, :modify_approvers_rules, project)
    end

    def can_modify_author_settings(project = @project)
      can?(current_user, :modify_merge_request_author_setting, project)
    end

    def can_modify_commiter_settings(project = @project)
      can?(current_user, :modify_merge_request_committer_setting, project)
    end

    def permanent_delete_message(project)
      message = _('This action deletes %{codeOpen}%{project_path_with_namespace}%{codeClose} and everything this project contains. %{strongOpen}There is no going back.%{strongClose}')
      html_escape(message) % remove_message_data(project)
    end

    def marked_for_removal_message(project)
      date = permanent_deletion_date(Time.now.utc)

      message = if project.feature_available?(:adjourned_deletion_for_projects_and_groups)
                  _("This action deletes %{codeOpen}%{project_path_with_namespace}%{codeClose} on %{date} and everything this project contains.")
                else
                  _("This action deletes %{codeOpen}%{project_path_with_namespace}%{codeClose} on %{date} and everything this project contains. %{strongOpen}There is no going back.%{strongClose}")
                end

      html_escape(message) % remove_message_data(project).merge(date: date)
    end

    def permanent_deletion_date(date)
      (date + ::Gitlab::CurrentSettings.deletion_adjourned_period.days).strftime('%F')
    end

    # Given the current GitLab configuration, check whether the GitLab URL for Kerberos is going to be different than the HTTP URL
    def alternative_kerberos_url?
      ::Gitlab.config.alternative_gitlab_kerberos_url?
    end

    def can_change_push_rule?(push_rule, rule, context)
      return true if push_rule.global?

      can?(current_user, :"change_#{rule}", context)
    end

    def ci_cd_projects_available?
      ::License.feature_available?(:ci_cd_projects) && import_sources_enabled?
    end

    override :remote_mirror_setting_enabled?
    def remote_mirror_setting_enabled?
      ::Gitlab::CurrentSettings.import_sources.any? && ::License.feature_available?(:ci_cd_projects) && ::Gitlab::CurrentSettings.current_application_settings.mirror_available
    end

    def merge_pipelines_available?
      return false unless @project.builds_enabled?

      @project.feature_available?(:merge_pipelines)
    end

    def merge_trains_available?
      return false unless @project.builds_enabled?

      @project.feature_available?(:merge_trains)
    end

    def size_limit_message(project)
      show_lfs = project.lfs_enabled? ? 'including LFS files' : ''

      "Max size of this project's repository, #{show_lfs}. For no limit, enter 0. To inherit the group/global value, leave blank."
    end

    override :membership_locked?
    def membership_locked?
      group = @project.group

      return false unless group

      group.membership_lock? ||
        ::Gitlab::CurrentSettings.lock_memberships_to_ldap? ||
        ::Gitlab::CurrentSettings.lock_memberships_to_saml?
    end

    def group_project_templates_count(group_id)
      if ::Feature.enabled?(:project_templates_without_min_access, current_user)
        projects_not_aimed_for_deletions_for(group_id).count do |project|
          can?(current_user, :download_code, project)
        end
      else
        projects_not_aimed_for_deletions_for(group_id).count
      end
    end

    def group_project_templates(group)
      if ::Feature.enabled?(:project_templates_without_min_access, current_user)
        projects_not_aimed_for_deletions_for(group.id).select do |project|
          can?(current_user, :download_code, project)
        end
      else
        group.projects.not_aimed_for_deletion
      end
    end

    def project_security_dashboard_config(project)
      if project.vulnerabilities.none?
        {
          has_vulnerabilities: 'false',
          has_jira_vulnerabilities_integration_enabled: project.configured_to_create_issues_from_vulnerabilities?.to_s,
          operational_configuration_path: new_project_security_policy_path(@project),
          empty_state_svg_path: image_path('illustrations/empty-state/empty-secure-md.svg'),
          security_dashboard_empty_svg_path: image_path('illustrations/empty-state/empty-secure-md.svg'),
          no_vulnerabilities_svg_path: image_path('illustrations/empty-state/empty-search-md.svg'),
          project_full_path: project.full_path,
          security_configuration_path: project_security_configuration_path(@project),
          can_admin_vulnerability: can?(current_user, :admin_vulnerability, project).to_s,
          new_vulnerability_path: new_project_security_vulnerability_path(@project)
        }.merge!(security_dashboard_pipeline_data(project))
      else
        {
          has_vulnerabilities: 'true',
          has_jira_vulnerabilities_integration_enabled: project.configured_to_create_issues_from_vulnerabilities?.to_s,
          project: { id: project.id, name: project.name },
          project_full_path: project.full_path,
          vulnerabilities_export_endpoint: expose_path(api_v4_security_projects_vulnerability_exports_path(id: project.id)),
          empty_state_svg_path: image_path('illustrations/security-dashboard-empty-state.svg'),
          security_dashboard_empty_svg_path: image_path('illustrations/empty-state/empty-secure-md.svg'),
          no_vulnerabilities_svg_path: image_path('illustrations/empty-state/empty-search-md.svg'),
          new_project_pipeline_path: new_project_pipeline_path(project),
          operational_configuration_path: new_project_security_policy_path(@project),
          auto_fix_mrs_path: project_merge_requests_path(@project, label_name: 'GitLab-auto-fix'),
          scanners: VulnerabilityScanners::ListService.new(project).execute.to_json,
          can_admin_vulnerability: can?(current_user, :admin_vulnerability, project).to_s,
          can_view_false_positive: can_view_false_positive?,
          security_configuration_path: project_security_configuration_path(@project),
          new_vulnerability_path: new_project_security_vulnerability_path(@project)
        }.merge!(security_dashboard_pipeline_data(project))
      end
    end

    def can_view_false_positive?
      project.licensed_feature_available?(:sast_fp_reduction).to_s
    end

    def can_create_feedback?(project, feedback_type)
      feedback = Vulnerabilities::Feedback.new(project: project, feedback_type: feedback_type)
      can?(current_user, :create_vulnerability_feedback, feedback)
    end

    def create_vulnerability_feedback_issue_path(project)
      if can_create_feedback?(project, :issue)
        project_vulnerability_feedback_index_path(project)
      end
    end

    def create_vulnerability_feedback_merge_request_path(project)
      if can_create_feedback?(project, :merge_request)
        project_vulnerability_feedback_index_path(project)
      end
    end

    def create_vulnerability_feedback_dismissal_path(project)
      if can_create_feedback?(project, :dismissal)
        project_vulnerability_feedback_index_path(project)
      end
    end

    def show_discover_project_security?(project)
      !!current_user &&
        ::Gitlab.com? &&
        !project.feature_available?(:security_dashboard) &&
        can?(current_user, :admin_namespace, project.root_ancestor)
    end

    def show_compliance_framework_badge?(project)
      project&.licensed_feature_available?(:custom_compliance_frameworks) && project&.compliance_framework_setting&.compliance_management_framework.present?
    end

    def scheduled_for_deletion?(project)
      project.marked_for_deletion_at.present?
    end

    def project_compliance_framework_app_data(project, can_edit)
      group = project.root_ancestor
      {
        group_name: group.name,
        group_path: group_path(group),
        empty_state_svg_path: image_path('illustrations/welcome/ee_trial.svg')
      }.tap do |data|
        if can_edit
          data[:add_framework_path] = "#{edit_group_path(group)}#js-compliance-frameworks-settings"
        end
      end
    end

    def proxied_site
      ::Gitlab::Geo.proxied_site(request.env)
    end

    override :http_clone_url_to_repo
    def http_clone_url_to_repo(project)
      proxied_site ? geo_proxied_http_url_to_repo(proxied_site, project) : super
    end

    override :ssh_clone_url_to_repo
    def ssh_clone_url_to_repo(project)
      proxied_site ? geo_proxied_ssh_url_to_repo(proxied_site, project) : super
    end

    def project_transfer_app_data(project)
      {
        full_path: project.full_path
      }
    end

    private

    def remove_message_data(project)
      {
        project_path_with_namespace: project.path_with_namespace,
        project: project.path,
        strongOpen: '<strong>'.html_safe,
        strongClose: '</strong>'.html_safe,
        codeOpen: '<code>'.html_safe,
        codeClose: '</code>'.html_safe
      }
    end

    def security_dashboard_pipeline_data(project)
      pipeline = project.latest_ingested_security_pipeline
      sbom_pipeline = project.latest_ingested_sbom_pipeline

      pipelines = {}

      if pipeline
        pipelines[:pipeline] = {
          id: pipeline.id,
          path: pipeline_path(pipeline),
          created_at: pipeline.created_at.to_fs(:iso8601),
          has_warnings: pipeline.has_security_report_ingestion_warnings?.to_s,
          has_errors: pipeline.has_security_report_ingestion_errors?.to_s,
          security_builds: {
            failed: {
              count: pipeline.latest_failed_security_builds.count,
              path: failures_project_pipeline_path(pipeline.project, pipeline)
            }
          }
        }
      end

      if sbom_pipeline
        pipelines[:sbom_pipeline] = {
          id: sbom_pipeline.id,
          path: pipeline_path(sbom_pipeline),
          created_at: sbom_pipeline.created_at.to_fs(:iso8601),
          has_warnings: "", # To be added in: https://gitlab.com/gitlab-org/gitlab/-/issues/366960
          has_errors: "" # To be added in: https://gitlab.com/gitlab-org/gitlab/-/issues/366960
        }
      end

      pipelines
    end

    def allowed_subgroups(group_id)
      current_user.available_subgroups_with_custom_project_templates(group_id)
    end

    def projects_not_aimed_for_deletions_for(group_id)
      ::Project
        .with_namespace
        .with_group
        .include_project_feature
        .with_group_saml_provider
        .with_invited_groups
        .in_namespace(allowed_subgroups(group_id))
        .not_aimed_for_deletion
    end
  end
end
