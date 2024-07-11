# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Requests
        class Anthropic < Base
          attr_reader :ai_client

          TEMPERATURE = 0.1
          STOP_WORDS = ["\n\nHuman", "Observation:"].freeze
          PROMPT_SIZE = 30_000

          def initialize(user, tracking_context: {})
            @user = user
            @ai_client = ::Gitlab::Llm::Anthropic::Client.new(user, tracking_context: tracking_context)
            @logger = Gitlab::Llm::Logger.build
          end

          def request(prompt)
            ai_client.stream(
              prompt: prompt[:prompt],
              **default_options.merge(prompt.fetch(:options, {}))
            ) do |data|
              logger.info(message: "Streaming error", error: data&.dig("error")) if data&.dig("error")

              content = data&.dig("completion").to_s
              yield content if block_given?
            end
          end

          private

          attr_reader :user, :logger

          def default_options
            {
              temperature: TEMPERATURE,
              stop_sequences: STOP_WORDS
            }
          end
        end
      end
    end
  end
end
