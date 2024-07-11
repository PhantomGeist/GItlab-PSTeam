# frozen_string_literal: true

module Admin
  class NamespaceLimitsController < Admin::ApplicationController
    feature_category :consumables_cost_management
    urgency :low

    before_action :check_gitlab_com

    def index; end

    def export_usage
      # rubocop:disable CodeReuse/Worker
      Namespaces::StorageUsageExportWorker.perform_async('free', current_user.id)
      # rubocop:enable CodeReuse/Worker

      flash[:notice] = _('CSV is being generated and will be emailed to you upon completion.')

      redirect_to admin_namespace_limits_path
    end

    private

    def check_gitlab_com
      not_found unless ::Gitlab::CurrentSettings.should_check_namespace_plan?
    end
  end
end
