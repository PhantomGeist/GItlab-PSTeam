# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Completions::GenerateTestFile, feature_category: :code_review_workflow do
  let(:prompt_class) { Gitlab::Llm::Templates::GenerateTestFile }
  let(:options) { { file_path: 'index.js' } }
  let(:response_modifier) { double }
  let(:response_service) { double }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request) }
  let(:params) do
    [user, merge_request, response_modifier, { options: { request_id: 'uuid', ai_action: :generate_test_file } }]
  end

  let(:prompt_message) do
    build(:ai_message, :generate_test_file, user: user, resource: merge_request, request_id: 'uuid')
  end

  subject { described_class.new(prompt_message, prompt_class, options) }

  describe '#execute' do
    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(generate_test_file_vertex: false)
      end

      it 'falls back to the OpenAI implementation' do
        allow_next_instance_of(::Gitlab::Llm::OpenAi::Completions::GenerateTestFile,
          prompt_message, prompt_class, options) do |completion|
          expect(completion).to receive(:execute)
        end

        subject.execute
      end
    end

    context 'when the text model returns an unsuccessful response' do
      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
          allow(client).to receive(:code).and_return(
            { error: 'Error' }.to_json
          )
        end
      end

      it 'publishes the error to the graphql subscription' do
        errors = { error: 'Error' }
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions).to receive(:new).with(errors.to_json)
                                                                                        .and_return(response_modifier)
        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_return(
          response_service
        )
        expect(response_service).to receive(:execute)

        subject.execute
      end
    end

    context 'when the text model returns a successful response' do
      let(:example_answer) { "AI generated test file" }

      let(:example_response) do
        {
          "predictions" => [
            {
              "candidates" => [
                {
                  "author" => "",
                  "content" => example_answer
                }
              ],
              "safetyAttributes" => {
                "categories" => ["Violent"],
                "scores" => [0.4000000059604645],
                "blocked" => false
              }
            }
          ],
          "deployedModelId" => "1",
          "model" => "projects/1/locations/us-central1/models/code-bison",
          "modelDisplayName" => "text-bison",
          "modelVersionId" => "1"
        }
      end

      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
          allow(client).to receive(:code).and_return(example_response.to_json)
        end
      end

      it 'publishes the content from the AI response' do
        expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions).to receive(:new).with(example_response.to_json)
                                                                                        .and_return(response_modifier)
        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_return(
          response_service
        )
        expect(response_service).to receive(:execute)

        subject.execute
      end

      context 'when an unexpected error is raised' do
        let(:error) { StandardError.new("Error") }

        before do
          allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
            allow(client).to receive(:code).and_raise(error)
          end
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
        end

        it 'records the error' do
          subject.execute
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
        end

        it 'publishes a generic error to the graphql subscription' do
          errors = { error: { message: 'An unexpected error has occurred.' } }
          expect(::Gitlab::Llm::VertexAi::ResponseModifiers::Predictions).to receive(:new).with(errors.to_json)
                                                                                          .and_return(response_modifier)
          expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_return(
            response_service
          )
          expect(response_service).to receive(:execute)

          subject.execute
        end
      end
    end
  end
end
