# frozen_string_literal: true

module EE
  module GraphqlTriggers
    extend ActiveSupport::Concern

    prepended do
      def self.ai_completion_response(message)
        subscription_arguments = {
          user_id: message.user.to_gid,
          ai_action: message.ai_action.to_s
        }

        if message.client_subscription_id && !message.user?
          subscription_arguments[:client_subscription_id] = message.client_subscription_id
        end

        ::GitlabSchema.subscriptions.trigger(:ai_completion_response, subscription_arguments, message.to_h)

        # Once all clients `ai_action` we can remove this trigger duplicate .
        # Clients that use the `ai_action` parameter to subscribe on, no longer need to subscribe on the
        # `resource_id`. This enables us to broadcast chat messages to clients, regardless of their `resource_id`.
        # https://gitlab.com/gitlab-org/gitlab/-/issues/423080
        ::GitlabSchema.subscriptions.trigger(
          :ai_completion_response,
          subscription_arguments.except(:ai_action).merge(resource_id: message.resource&.to_global_id),
          message.to_h)
      end

      def self.issuable_weight_updated(issuable)
        ::GitlabSchema.subscriptions.trigger(:issuable_weight_updated, { issuable_id: issuable.to_gid }, issuable)
      end

      def self.issuable_iteration_updated(issuable)
        ::GitlabSchema.subscriptions.trigger(:issuable_iteration_updated, { issuable_id: issuable.to_gid }, issuable)
      end

      def self.issuable_health_status_updated(issuable)
        ::GitlabSchema.subscriptions.trigger(
          :issuable_health_status_updated, { issuable_id: issuable.to_gid }, issuable
        )
      end

      def self.issuable_epic_updated(issuable)
        ::GitlabSchema.subscriptions.trigger(:issuable_epic_updated, { issuable_id: issuable.to_gid }, issuable)
      end
    end
  end
end
