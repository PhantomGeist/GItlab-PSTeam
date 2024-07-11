# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module Completions
        class SummarizeReview < Gitlab::Llm::Completions::Base
          DEFAULT_ERROR = 'An unexpected error has occurred.'

          def execute
            draft_notes = merge_request.draft_notes.authored_by(user)
            return if draft_notes.empty?

            response = response_for(user, draft_notes)
            response_modifier = ::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions.new(response)

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, merge_request, response_modifier, options: response_options
            ).execute

            response_modifier
          rescue StandardError => error
            Gitlab::ErrorTracking.track_exception(error)

            response_modifier = ::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions.new(
              { error: { message: DEFAULT_ERROR } }.to_json
            )

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, merge_request, response_modifier, options: response_options
            ).execute

            response_modifier
          end

          private

          def merge_request
            resource
          end

          def response_for(user, draft_notes)
            Gitlab::Llm::VertexAi::Client
              .new(user, tracking_context: tracking_context)
              .text(content: ai_prompt_class.new(draft_notes).to_prompt)
          end
        end
      end
    end
  end
end
