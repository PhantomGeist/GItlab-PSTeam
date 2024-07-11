# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::CategorizeQuestion, feature_category: :duo_chat do
  let(:user) { build(:user) }
  let(:question) { 'what is the issue' }

  subject { described_class.new(user, { question: question }) }

  describe '#to_prompt' do
    it 'includes question' do
      prompt = subject.to_prompt

      expect(prompt).to include(question)
    end

    it 'includes xml part' do
      prompt = subject.to_prompt

      expect(prompt).to include('<?xml version="1.0" encoding="UTF-8"?><root><row>')
    end
  end
end
