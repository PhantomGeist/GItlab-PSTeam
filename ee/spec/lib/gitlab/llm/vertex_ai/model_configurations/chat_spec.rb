# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::ModelConfigurations::Chat, feature_category: :ai_abstraction_layer do
  let_it_be(:host) { 'example-env.com' }
  let_it_be(:project) { 'cllm' }

  before do
    stub_application_setting(vertex_ai_host: host)
    stub_application_setting(vertex_ai_project: project)
  end

  describe '#payload' do
    it 'returns default payload' do
      messages = [
        { author: 'user', content: 'foo' },
        { author: 'content', content: 'bar' },
        { author: 'user', content: 'baz' }
      ]

      expect(subject.payload(messages)).to eq(
        {
          instances: [
            {
              messages: messages
            }
          ],
          parameters: Gitlab::Llm::VertexAi::Configuration.default_payload_parameters
        }
      )
    end
  end

  describe '#url' do
    it 'returns correct url replacing default value' do
      expect(subject.url).to eq(
        'https://example-env.com/v1/projects/cllm/locations/us-central1/publishers/google/models/chat-bison:predict'
      )
    end
  end

  describe '#as_json' do
    it 'returns serializable attributes' do
      attrs = {
        vertex_ai_host: host,
        vertex_ai_project: project,
        model: described_class::NAME,
        temperature: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TEMPERATURE,
        maxOutputTokens: Gitlab::Llm::VertexAi::Configuration::DEFAULT_MAX_OUTPUT_TOKENS,
        topK: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TOP_K,
        topP: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TOP_P
      }

      expect(subject.as_json).to eq(attrs)
    end
  end
end
