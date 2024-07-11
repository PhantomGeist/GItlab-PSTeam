# frozen_string_literal: true

module Gitlab
  module Llm
    module OpenAi
      module Completions
        class ExplainCode < Gitlab::Llm::Completions::Base
          def execute
            client_options = ai_prompt_class.get_options(options[:messages])

            ai_response = Gitlab::Llm::OpenAi::Client.new(user, tracking_context: tracking_context)
              .chat(content: nil, **client_options)

            response_modifier = Gitlab::Llm::OpenAi::ResponseModifiers::Chat.new(ai_response)

            ::Gitlab::Llm::GraphqlSubscriptionResponseService
              .new(user, project, response_modifier, options: response_options)
              .execute

            response_modifier
          end

          private

          def project
            resource
          end
        end
      end
    end
  end
end
