# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module Completions
        class FillInMergeRequestTemplate < Gitlab::Llm::Completions::Base
          def execute
            response = response_for(user, project, options)
            response_modifier = ::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions.new(response)

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, project, response_modifier, options: response_options
            ).execute

            response_modifier
          end

          private

          def project
            resource
          end

          def response_for(user, project, options)
            template = ai_prompt_class.new(user, project, options)
            request(user, template)
          end

          def request(user, template)
            ::Gitlab::Llm::VertexAi::Client
              .new(user, tracking_context: tracking_context)
              .text(content: template.to_prompt)
          end
        end
      end
    end
  end
end
