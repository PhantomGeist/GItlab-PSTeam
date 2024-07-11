# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Completions::CategorizeQuestion, feature_category: :duo_chat do
  describe '#execute' do
    let(:user) { build(:user) }
    let(:ai_client) { ::Gitlab::Llm::Anthropic::Client.new(nil) }
    let(:response) {  { 'completion' => answer.to_s } }

    let(:prompt_message) do
      build(:ai_chat_message, :categorize_question, user: user, resource: user, request_id: 'uuid')
    end

    let(:options) { { question: 'What is the pipeline?' } }

    subject(:categorize_action) do
      described_class.new(prompt_message, ::Gitlab::Llm::Templates::CategorizeQuestion, **options).execute
    end

    before do
      allow_next_instance_of(::Gitlab::Llm::Anthropic::Client) do |ai_client|
        allow(ai_client).to receive(:complete).and_return(response)
      end
    end

    context 'with valid response' do
      let(:answer) { { detailed_category: "Summarize issue", category: 'Summarize something' }.to_json }

      it 'tracks event' do
        categorize_action

        expect_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          property: 'uuid',
          user: user,
          context: [{
            schema: described_class::SCHEMA_URL,
            data: { 'detailed_category' => "Summarize issue", 'category' => 'Summarize something' }
          }]
        )
      end
    end

    context 'with incomplete response' do
      let(:answer) { { category: 'Summarize something' }.to_json }

      it 'does not track event' do
        categorize_action

        expect_no_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          property: 'uuid',
          user: user,
          context: []
        )
      end
    end

    context 'with invalid response' do
      let(:answer) { "invalid" }

      it 'does not track event' do
        categorize_action

        expect_no_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          property: 'uuid',
          user: user,
          context: []
        )
      end
    end
  end
end
