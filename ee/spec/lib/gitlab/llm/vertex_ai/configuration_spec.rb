# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Configuration, feature_category: :ai_abstraction_layer do
  let(:host) { "example-#{SecureRandom.hex(8)}.com" }
  let(:url) { "https://#{host}/api" }
  let(:model_config) { instance_double('Gitlab::Llm::VertexAi::ModelConfigurations::CodeChat', host: host) }

  subject(:configuration) { described_class.new(model_config: model_config) }

  before do
    stub_ee_application_setting(vertex_ai_host: host)
  end

  describe '#access_token' do
    let(:current_token) { SecureRandom.uuid }

    it 'delegates to Llm::VertexAiAccessTokenService' do
      token_loader = instance_double(Gitlab::Llm::VertexAi::TokenLoader)
      allow(Gitlab::Llm::VertexAi::TokenLoader).to receive(:new).and_return(token_loader)
      allow(token_loader).to receive(:current_token).and_return(current_token)

      expect(configuration.access_token).to eq current_token
    end
  end

  describe '#headers' do
    before do
      allow(configuration).to receive(:access_token).and_return('123')
    end

    it 'returns headers with text host header replacing host value' do
      expect(configuration.headers).to eq(
        {
          'Accept' => 'application/json',
          'Authorization' => 'Bearer 123',
          'Host' => host,
          'Content-Type' => 'application/json'
        }
      )
    end
  end

  describe '.default_payload_parameters' do
    it 'returns the default payload parameters' do
      expect(described_class.default_payload_parameters).to eq(
        {
          temperature: 0.2,
          maxOutputTokens: 1024,
          topK: 40,
          topP: 0.95
        }
      )
    end
  end

  describe '.payload_parameters' do
    it 'returns the default payload parameters merged with overwritten parameters' do
      expect(described_class.payload_parameters).to eq(
        {
          temperature: 0.2,
          maxOutputTokens: 1024,
          topK: 40,
          topP: 0.95
        }
      )

      new_payload = {
        temperature: 0.5,
        maxOutputTokens: 4098,
        topK: 20,
        topP: 0.91
      }

      expect(described_class.payload_parameters(new_payload)).to eq(new_payload)
    end
  end

  describe 'methods delegated to model config' do
    it 'delegates host, url and payload to model_config' do
      is_expected.to delegate_method(:host).to(:model_config)
      is_expected.to delegate_method(:url).to(:model_config)
      is_expected.to delegate_method(:payload).to(:model_config)
    end
  end
end
