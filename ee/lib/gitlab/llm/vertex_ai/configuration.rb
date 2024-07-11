# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      class Configuration
        DEFAULT_TEMPERATURE = 0.2
        DEFAULT_MAX_OUTPUT_TOKENS = 1024
        DEFAULT_TOP_K = 40
        DEFAULT_TOP_P = 0.95

        delegate :host, :url, :payload, :as_json, to: :model_config

        def initialize(model_config:)
          @model_config = model_config
        end

        def self.default_payload_parameters
          {
            temperature: DEFAULT_TEMPERATURE,
            maxOutputTokens: DEFAULT_MAX_OUTPUT_TOKENS,
            topK: DEFAULT_TOP_K,
            topP: DEFAULT_TOP_P
          }
        end

        def self.payload_parameters(params = {})
          default_payload_parameters.merge(params)
        end

        def access_token
          TokenLoader.new.current_token
        end

        def headers
          {
            "Accept" => "application/json",
            "Authorization" => "Bearer #{access_token}",
            "Host" => model_config.host,
            "Content-Type" => "application/json"
          }
        end

        private

        attr_reader :model_config
      end
    end
  end
end
