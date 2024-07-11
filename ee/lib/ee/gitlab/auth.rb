# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :unavailable_ai_features_scopes_for_resource
      def unavailable_ai_features_scopes_for_resource(resource)
        if ::Gitlab::Llm::ResourceAccess.ai_enabled_for_resource?(resource)
          []
        else
          super
        end
      end
    end
  end
end
