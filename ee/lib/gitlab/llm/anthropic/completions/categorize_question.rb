# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class CategorizeQuestion < Gitlab::Llm::Completions::Base
          SCHEMA_URL = 'iglu:com.gitlab/ai_question_category/jsonschema/1-0-0'

          REQUIRED_KEYS = %w[detailed_category category].freeze
          OPTIONAL_KEYS = [].freeze
          PERMITTED_KEYS = REQUIRED_KEYS + OPTIONAL_KEYS

          def execute
            @ai_client = ::Gitlab::Llm::Anthropic::Client.new(user, tracking_context: tracking_context)
            response = response_for(user, options)
            @logger = Gitlab::Llm::Logger.build

            process_response(response, user)
          end

          private

          def response_for(user, options)
            template = ai_prompt_class.new(user, options)
            request(template)
          end

          def request(template)
            @ai_client.complete(
              prompt: template.to_prompt
            )&.dig("completion").to_s.strip
          end

          def process_response(response, user)
            json = Gitlab::Json.parse(response)

            return unless json

            track(user, json)

          rescue JSON::ParserError
            error_message = "JSON has an invalid format."
            @logger.error(message: "Error", class: self.class.to_s, error: error_message)
          end

          def track(user, json)
            return unless contains_categories?(json)

            context = SnowplowTracker::SelfDescribingJson.new(SCHEMA_URL, json.slice(*PERMITTED_KEYS))

            Gitlab::Tracking.event(
              self.class.to_s,
              "ai_question_category",
              context: [context],
              property: tracking_context[:request_id],
              user: user
            )
          end

          def contains_categories?(json)
            REQUIRED_KEYS.each do |key|
              return false unless json.has_key?(key)
            end
          end
        end
      end
    end
  end
end
