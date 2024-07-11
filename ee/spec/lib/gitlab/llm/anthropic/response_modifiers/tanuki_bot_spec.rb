# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot, feature_category: :duo_chat do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:current_user) { create(:user) }
  let_it_be(:vertex_embedding) { create(:vertex_gitlab_documentation) }

  let(:text) { 'some ai response text' }
  let(:ai_response) { { completion: "#{text} ATTRS: CNT-IDX-#{record_id}" }.to_json }
  let(:record_id) { vertex_embedding.id }

  describe '#response_body' do
    let(:expected_response) { text }

    subject { described_class.new(ai_response, current_user).response_body }

    it { is_expected.to eq(text) }
  end

  describe '#extras' do
    subject { described_class.new(ai_response, current_user).extras }

    context 'when the ids match existing documents' do
      let(:sources) { [vertex_embedding.metadata.merge(source_url: vertex_embedding.url)] }

      it 'fills sources' do
        expect(subject).to eq(sources: sources)
      end
    end

    context "when the ids don't match any documents" do
      let(:record_id) { non_existing_record_id }

      it 'sets extras as empty' do
        expect(subject).to eq(sources: [])
      end
    end

    context "when the there are no ids" do
      let(:ai_response) { { completion: "#{text} ATTRS:" }.to_json }

      it 'sets extras as empty' do
        expect(subject).to eq(sources: [])
      end
    end

    context "when the message contains the text I don't know" do
      let(:text) { "I don't know the answer to your question" }
      let(:record_id) { non_existing_record_id }

      it 'sets extras as empty' do
        expect(subject).to eq(sources: [])
      end
    end
  end
end
