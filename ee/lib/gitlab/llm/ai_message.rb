# frozen_string_literal: true

module Gitlab
  module Llm
    class AiMessage
      include ActiveModel::AttributeAssignment

      ROLE_USER = 'user'
      ROLE_ASSISTANT = 'assistant'
      ROLE_SYSTEM = 'system'
      ALLOWED_ROLES = [ROLE_USER, ROLE_ASSISTANT, ROLE_SYSTEM].freeze

      ATTRIBUTES_LIST = [
        :id, :request_id, :content, :role, :timestamp, :errors, :extras,
        :user, :resource, :ai_action, :client_subscription_id, :type, :chunk_id
      ].freeze

      attr_accessor(*ATTRIBUTES_LIST)

      def self.for(action:)
        if action.to_s == 'chat'
          ChatMessage
        else
          self
        end
      end

      def initialize(attributes = {})
        attributes = attributes.with_indifferent_access.slice(*ATTRIBUTES_LIST)

        raise ArgumentError, "Invalid role '#{attributes['role']}'" unless ALLOWED_ROLES.include?(attributes['role'])
        raise ArgumentError, "User is required" unless attributes['user']

        assign_attributes(attributes)

        @id ||= SecureRandom.uuid
        @timestamp ||= Time.current
        @errors ||= []
      end

      def to_h
        ATTRIBUTES_LIST.index_with do |attr|
          public_send(attr) # rubocop:disable GitlabSecurity/PublicSend
        end.compact.with_indifferent_access
      end

      def save!
        raise NoMethodError, "Can't save regular AiMessage."
      end

      def to_global_id
        ::Gitlab::GlobalId.build(self)
      end

      def size
        content&.size.to_i
      end

      def user?
        role == ROLE_USER
      end

      def system?
        role == ROLE_SYSTEM
      end

      def assistant?
        role == ROLE_ASSISTANT
      end
    end
  end
end
