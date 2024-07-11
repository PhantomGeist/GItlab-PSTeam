# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::OpenAi::ResponseModifiers::Chat, feature_category: :duo_chat do
  let(:ai_response) { { choices: [{ message: { content: 'hello' } }] }.to_json }

  it 'parses content from the ai response' do
    expect(described_class.new(ai_response).response_body).to eq('hello')
  end
end
