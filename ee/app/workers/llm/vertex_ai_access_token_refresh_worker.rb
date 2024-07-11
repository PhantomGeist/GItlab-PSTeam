# frozen_string_literal: true

module Llm
  class VertexAiAccessTokenRefreshWorker
    include ApplicationWorker

    idempotent!
    data_consistency :delayed
    feature_category :ai_abstraction_layer
    urgency :low
    deduplicate :until_executed

    def perform
      return unless vertex_enabled?

      Gitlab::Llm::VertexAi::TokenLoader.new.refresh_token!
    end

    private

    def vertex_enabled?
      (Feature.enabled?(:openai_experimentation) || Feature.enabled?(:ai_global_switch, type: :ops)) &&
        ::Gitlab::CurrentSettings.vertex_ai_project.present?
    end
  end
end
