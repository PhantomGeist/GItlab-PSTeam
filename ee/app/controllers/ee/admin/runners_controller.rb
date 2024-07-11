# frozen_string_literal: true

module EE
  module Admin
    module RunnersController
      extend ActiveSupport::Concern

      prepended do
        before_action(only: [:index]) { push_licensed_feature(:runner_performance_insights) }
        before_action(only: [:index, :show]) do
          push_licensed_feature(:runner_upgrade_management) if ::Gitlab::Ci::RunnerReleases.instance.enabled?
        end
        before_action(only: [:new, :show, :edit]) { push_licensed_feature(:runner_maintenance_note) }
        before_action(only: [:dashboard]) { push_frontend_feature_flag(:clickhouse_ci_analytics, current_user) }
      end

      def dashboard
        render_404 unless License.feature_available?(:runner_performance_insights)
      end
    end
  end
end
