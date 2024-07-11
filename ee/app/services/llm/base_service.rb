# frozen_string_literal: true

module Llm
  class BaseService
    INVALID_MESSAGE = 'AI features are not enabled or resource is not permitted to be sent.'

    def initialize(user, resource, options = {})
      @user = user
      @resource = resource
      @options = options
      @logger = Gitlab::Llm::Logger.build
    end

    def execute
      unless valid?
        logger.info(message: "Returning from Service due to validation")
        return error(INVALID_MESSAGE)
      end

      result = perform

      result.is_a?(ServiceResponse) ? result : success(ai_message: prompt_message)
    end

    def valid?
      return false if resource.respond_to?(:resource_parent) && !resource.resource_parent.member?(user)

      ai_integration_enabled? && user_can_send_to_ai?
    end

    private

    attr_reader :user, :resource, :options, :logger

    def perform
      raise NotImplementedError
    end

    def ai_integration_enabled?
      Feature.enabled?(:openai_experimentation) || Feature.enabled?(:ai_global_switch, type: :ops)
    end

    # https://gitlab.com/gitlab-org/gitlab/-/issues/413520
    def user_can_send_to_ai?
      return true unless ::Gitlab.com?

      user.any_group_with_ai_available?
    end

    def prompt_message
      @prompt_message ||= build_prompt_message
    end

    def build_prompt_message(attributes = options)
      action_name = attributes[:ai_action] || ai_action
      message_attributes = {
        request_id: SecureRandom.uuid,
        content: content(action_name),
        role: ::Gitlab::Llm::AiMessage::ROLE_USER,
        ai_action: action_name,
        user: user,
        resource: resource
      }.merge(attributes)

      ::Gitlab::Llm::AiMessage.for(action: action_name).new(message_attributes)
    end

    def content(action_name)
      action_name.to_s.humanize
    end

    def schedule_completion_worker(job_options = options)
      message = prompt_message

      job_options = job_options.merge(request_id: message.request_id)

      logger.debug(
        message: "Enqueuing CompletionWorker",
        user_id: message.user.id,
        resource_id: message.resource&.id,
        resource_class: message.resource&.class&.name,
        request_id: message.request_id,
        action_name: message.ai_action,
        options: job_options
      )

      ::Llm::CompletionWorker.perform_async(
        message.user.id, message.resource&.id, message.resource&.class&.name, message.ai_action, job_options)
    end

    def success(payload)
      ServiceResponse.success(payload: payload)
    end

    def error(message)
      ServiceResponse.error(message: message)
    end
  end
end
