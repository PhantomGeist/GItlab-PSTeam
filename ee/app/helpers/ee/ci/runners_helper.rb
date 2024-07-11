# frozen_string_literal: true

module EE
  module Ci
    module RunnersHelper
      include ::Gitlab::Utils::StrongMemoize
      extend ::Gitlab::Utils::Override

      BUY_PIPELINE_MINUTES_NOTIFICATION_DOT = 'buy_pipeline_minutes_notification_dot'

      override :admin_runners_data_attributes
      def admin_runners_data_attributes
        attributes = super

        if License.feature_available?(:runner_performance_insights)
          attributes = attributes.merge(runner_dashboard_path: dashboard_admin_runners_path)
        end

        attributes
      end

      override :toggle_shared_runners_settings_data
      def toggle_shared_runners_settings_data(project)
        super.merge(is_credit_card_validation_required: validate_credit_card?(project).to_s)
      end

      def validate_credit_card?(project)
        !current_user.has_required_credit_card_to_enable_shared_runners?(project)
      end

      def show_buy_pipeline_minutes?(project, namespace)
        return false unless ::Gitlab::Saas.feature_available?(:purchases_additional_minutes)

        show_out_of_pipeline_minutes_notification?(project, namespace)
      end

      def show_pipeline_minutes_notification_dot?(project, namespace)
        return false unless ::Gitlab::Saas.feature_available?(:purchases_additional_minutes)
        return false if notification_dot_acknowledged?

        show_out_of_pipeline_minutes_notification?(project, namespace)
      end

      def show_buy_pipeline_with_subtext?(project, namespace)
        return false unless ::Gitlab::Saas.feature_available?(:purchases_additional_minutes)
        return false unless notification_dot_acknowledged?

        show_out_of_pipeline_minutes_notification?(project, namespace)
      end

      def root_ancestor_namespace(project, namespace)
        (project || namespace).root_ancestor
      end

      private

      def notification_dot_acknowledged?
        strong_memoize(:notification_dot_acknowledged) do
          user_dismissed?(BUY_PIPELINE_MINUTES_NOTIFICATION_DOT)
        end
      end

      def show_out_of_pipeline_minutes_notification?(project, namespace)
        strong_memoize(:show_out_of_pipeline_minutes_notification) do
          next unless project&.persisted? || namespace&.persisted?

          ::Ci::Minutes::Notification.new(project, namespace).show?(current_user)
        end
      end
    end
  end
end
