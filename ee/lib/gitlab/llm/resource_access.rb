# frozen_string_literal: true

module Gitlab
  module Llm
    module ResourceAccess
      def self.ai_enabled_for_resource?(resource)
        case resource
        when User
          resource.any_group_with_ai_available?
        when Project
          check_namespace_settings(resource.namespace.root_ancestor.namespace_settings)
        when Group
          check_namespace_settings(resource.root_ancestor.namespace_settings)
        else
          false
        end
      end

      def self.check_namespace_settings(namespace_settings)
        return false unless namespace_settings

        namespace_settings.third_party_ai_features_enabled && namespace_settings.experiment_features_enabled
      end
    end
  end
end
