# frozen_string_literal: true

module NamespaceSettings
  class AiRelatedSettingsChangedEvent < ::Gitlab::EventStore::Event
    AI_RELATED_SETTINGS = %w[third_party_ai_features_enabled experiment_features_enabled].freeze

    def schema
      {
        'type' => 'object',
        'properties' => {
          'group_id' => { 'type' => 'integer' }
        },
        'required' => %w[group_id]
      }
    end
  end
end
