# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Completions::ExplainCode, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }

  let(:response_body) { 'consequent response' }
  let(:template_class) { ::Gitlab::Llm::VertexAi::Templates::ExplainCode }
  let(:options) do
    {
      messages: [{
        'role' => 'system',
        'content' => 'You are a knowledgeable assistant explaining to an engineer'
      }, {
        'role' => 'user',
        'content' => 'some initial request'
      }, {
        'role' => 'assistant',
        'content' => 'some response'
      }, {
        'role' => 'user',
        'content' => 'consequent request'
      }]
    }
  end

  let(:ai_template) do
    {
      instances: [
        messages: [{
          'author' => 'user',
          'content' => "You are a knowledgeable assistant explaining to an engineer\nsome initial request"
        }, {
          'author' => 'content',
          'content' => 'some response'
        }, {
          'author' => 'user',
          'content' => 'consequent request'
        }]
      ],
      parameters: {
        maxOutputTokens: 300,
        temperature: 0.3,
        topK: 40,
        topP: 0.95
      }
    }
  end

  let(:ai_response) do
    {
      'predictions' => [
        {
          "candidates" => [
            {
              "content" => response_body,
              "author" => "assistant"
            }
          ]
        }
      ]
    }.to_json
  end

  let(:tracking_context) { { request_id: 'uuid', action: :explain_code } }

  let(:prompt_message) do
    build(:ai_message, :explain_code, user: user, resource: project, request_id: 'uuid')
  end

  subject(:explain_code) { described_class.new(prompt_message, template_class, options).execute }

  describe "#execute" do
    it 'performs an Vertex AI request' do
      expect_next_instance_of(Gitlab::Llm::VertexAi::Client, user, tracking_context: tracking_context) do |instance|
        expect(instance).to receive(:chat).with(content: nil, **ai_template).and_return(ai_response)
      end

      params = [user, project, anything, { options: { request_id: 'uuid', ai_action: :explain_code } }]

      expect(Gitlab::Llm::VertexAi::ResponseModifiers::Predictions).to receive(:new).with(ai_response).and_call_original
      expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_call_original

      explain_code
    end
  end
end
