# frozen_string_literal: true

module Gitlab
  module Llm
    class GraphqlSubscriptionResponseService < BaseService
      def initialize(user, resource, response_modifier, options:)
        @user = user
        @resource = resource
        @response_modifier = response_modifier
        @options = options
        @logger = Gitlab::Llm::Logger.build
      end

      def response_message
        @response_message ||= begin
          data = options.slice(*%i[request_id type chunk_id role ai_action client_subscription_id])
          data[:role] ||= AiMessage::ROLE_ASSISTANT
          data.merge!(
            user: user,
            resource: resource,
            content: response_modifier.response_body,
            errors: response_modifier.errors,
            extras: response_modifier.extras
          )

          AiMessage.for(action: data[:ai_action]).new(data.compact)
        end
      end

      def execute
        return unless user

        response_message.save! if save_message?

        GraphqlTriggers.ai_completion_response(response_message)

        success(ai_message: response_message)
      end

      private

      attr_reader :user, :resource, :response_modifier, :options, :logger

      def save_message?
        response_message.is_a?(ChatMessage) &&
          !response_message.type &&
          !response_message.chunk_id
      end
    end
  end
end
