# frozen_string_literal: true

module SecurityHelper
  def instance_security_dashboard_data
    {
      no_vulnerabilities_svg_path: image_path('illustrations/empty-state/empty-search-md.svg'),
      empty_state_svg_path: image_path('illustrations/empty-state/empty-radar-md.svg'),
      security_dashboard_empty_svg_path: image_path('illustrations/empty-state/empty-secure-md.svg'),
      project_add_endpoint: security_projects_path,
      project_list_endpoint: security_projects_path,
      instance_dashboard_settings_path: settings_security_dashboard_path,
      vulnerabilities_export_endpoint: expose_path(api_v4_security_vulnerability_exports_path),
      can_admin_vulnerability: can_admin_vulnerability?,
      false_positive_doc_url: help_page_path('user/application_security/vulnerabilities/index'),
      can_view_false_positive: can_view_false_positive?,
      has_projects: instance_security_dashboard.has_projects?.to_s
    }
  end

  def can_view_false_positive?
    ::License.feature_available?(:sast_fp_reduction).to_s
  end

  def security_dashboard_unavailable_view_data
    {
      empty_state_svg_path: image_path('illustrations/security-dashboard-empty-state.svg'),
      is_unavailable: "true"
    }
  end

  def instance_security_settings_data
    {
      is_auditor: current_user.auditor?.to_s
    }
  end

  private

  def can_admin_vulnerability?
    (!current_user.auditor? &&
      instance_security_dashboard.has_projects? &&
      instance_security_dashboard.projects.all? { |project| current_user.can?(:admin_vulnerability, project) }
    ).to_s
  end

  def instance_security_dashboard
    @_instance_security_dashboard ||= InstanceSecurityDashboard.new(current_user)
  end
end
