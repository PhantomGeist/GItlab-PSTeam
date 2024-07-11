# frozen_string_literal: true

module Analytics
  module AnalyticsDashboardsHelper
    def analytics_dashboards_list_app_data(namespace)
      is_project = project?(namespace)
      is_group = group?(namespace)
      can_read_product_analytics = can?(current_user, :read_product_analytics, namespace)

      {
        namespace_id: namespace.id,
        is_project: is_project.to_s,
        is_group: is_group.to_s,
        dashboard_project: analytics_dashboard_pointer_project(namespace)&.to_json,
        can_configure_dashboards_project: can_configure_dashboards_project?(namespace).to_s,
        tracking_key: can_read_product_analytics && is_project ? tracking_key(namespace) : nil,
        collector_host: can_read_product_analytics ? collector_host(namespace) : nil,
        chart_empty_state_illustration_path: image_path('illustrations/chart-empty-state.svg'),
        dashboard_empty_state_illustration_path: image_path('illustrations/security-dashboard-empty-state.svg'),
        analytics_settings_path: analytics_settings_path(namespace),
        namespace_name: namespace.name,
        namespace_full_path: namespace.full_path,
        features: is_project ? enabled_analytics_features(namespace).to_json : [].to_json,
        router_base: router_base(namespace)
      }
    end

    def analytics_project_settings_data(project)
      can_read_product_analytics = can?(current_user, :read_product_analytics, project)

      {
        tracking_key: can_read_product_analytics ? tracking_key(project) : nil,
        collector_host: can_read_product_analytics ? collector_host(project) : nil,
        dashboards_path: project_analytics_dashboards_path(project)
      }
    end

    private

    def project?(namespace)
      namespace.is_a?(Project)
    end

    def group?(namespace)
      namespace.is_a?(Group)
    end

    def collector_host(project)
      if project?(project)
        ::ProductAnalytics::Settings.for_project(project).product_analytics_data_collector_host
      else
        ::Gitlab::CurrentSettings.product_analytics_data_collector_host
      end
    end

    def tracking_key(project)
      project.project_setting.product_analytics_instrumentation_key
    end

    def enabled_analytics_features(project)
      [].tap do |features|
        features << :product_analytics if product_analytics_enabled?(project)
      end
    end

    def product_analytics_enabled?(project)
      ::ProductAnalytics::Settings.for_project(project).enabled? &&
        ::Feature.enabled?(:product_analytics_dashboards, project) &&
        project.licensed_feature_available?(:product_analytics) &&
        can?(current_user, :read_product_analytics, project)
    end

    def can_configure_dashboards_project?(namespace)
      return false unless project?(namespace)

      can?(current_user, :admin_project, namespace)
    end

    def analytics_dashboard_pointer_project(namespace)
      return unless namespace.analytics_dashboards_pointer

      pointer_project = namespace.analytics_dashboards_pointer.target_project

      { id: pointer_project.id, full_path: pointer_project.full_path, name: pointer_project.name }
    end

    def router_base(namespace)
      return project_analytics_dashboards_path(namespace) if project?(namespace)

      group_analytics_dashboards_path(namespace)
    end

    def analytics_settings_path(namespace)
      settings_path =
        if project?(namespace)
          project_settings_analytics_path(namespace)
        else
          edit_group_path(namespace)
        end

      "#{settings_path}#js-analytics-dashboards-settings"
    end
  end
end
