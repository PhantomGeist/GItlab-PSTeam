# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::VertexAiAccessTokenRefreshWorker, feature_category: :ai_abstraction_layer do
  before do
    stub_ee_application_setting(vertex_ai_project: 'my-gcp-project')
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe '#perform' do
    it 'generates a new token and stores it in the database' do
      stub_ee_application_setting(vertex_ai_credentials: 'sekret')
      token_loader = instance_double(Gitlab::Llm::VertexAi::TokenLoader)
      allow(Gitlab::Llm::VertexAi::TokenLoader).to receive(:new).and_return(token_loader)
      allow(token_loader).to receive(:refresh_token!)

      described_class.new.perform

      expect(token_loader).to have_received(:refresh_token!)
    end
  end

  context 'when AI feature flag not enabled' do
    it 'is a no-op' do
      stub_ee_application_setting(vertex_ai_credentials: 'sekret')
      stub_feature_flags(openai_experimentation: false)
      token_loader = instance_double(Gitlab::Llm::VertexAi::TokenLoader)
      allow(Gitlab::Llm::VertexAi::TokenLoader).to receive(:new).and_return(token_loader)
      allow(token_loader).to receive(:refresh_token!)

      described_class.new.perform

      expect(token_loader).not_to have_received(:refresh_token!)
    end
  end

  context 'when Vertex is not configured' do
    it 'is a no-op' do
      stub_ee_application_setting(vertex_ai_project: nil)
      token_loader = instance_double(Gitlab::Llm::VertexAi::TokenLoader)
      allow(Gitlab::Llm::VertexAi::TokenLoader).to receive(:new).and_return(token_loader)
      allow(token_loader).to receive(:refresh_token!)

      described_class.new.perform

      expect(token_loader).not_to have_received(:refresh_token!)
    end
  end
end
