# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiMessage, feature_category: :duo_chat do
  subject { described_class.new(data) }

  let(:data) do
    {
      timestamp: timestamp,
      id: 'uuid',
      request_id: 'original_request_id',
      errors: ['some error1', 'another error'],
      role: 'user',
      content: 'response',
      ai_action: 'chat',
      client_subscription_id: 'client_subscription_id',
      user: build_stubbed(:user),
      resource: build_stubbed(:project),
      chunk_id: 1,
      type: 'tool'
    }
  end

  let(:timestamp) { 1.year.ago }

  describe 'defaults' do
    it 'sets default timestamp', :freeze_time do
      expect(described_class.new(data.except(:timestamp)).timestamp).to eq(Time.current)
    end

    it 'generates id' do
      allow(SecureRandom).to receive(:uuid).once.and_return('123')

      expect(described_class.new(data.except(:id)).id).to eq('123')
    end
  end

  describe 'validations' do
    it 'raises an error when role is absent' do
      expect do
        described_class.new(data.except(:role))
      end.to raise_error(ArgumentError)
    end

    it 'raises an error when role is not from the list' do
      expect do
        described_class.new(data.merge(role: 'not_a_role'))
      end.to raise_error(ArgumentError)
    end
  end

  describe '#to_global_id' do
    it 'returns global ID' do
      expect(subject.to_global_id.to_s).to eq('gid://gitlab/Gitlab::Llm::AiMessage/uuid')
    end
  end

  describe '#size' do
    it 'returns 0 if content is missing' do
      data[:content] = nil

      expect(subject.size).to eq(0)
    end

    it 'returns size of the content if present' do
      expect(subject.size).to eq(data[:content].size)
    end
  end

  describe '#save!' do
    it 'raises NoMethodError' do
      expect { subject.save! }.to raise_error(NoMethodError, "Can't save regular AiMessage.")
    end
  end

  describe '#to_h' do
    it 'returns hash with all attributes' do
      expect(subject.to_h).to eq(data.stringify_keys)
    end
  end

  describe 'role predicates' do
    context 'when role is user' do
      it { is_expected.to be_user }
      it { is_expected.not_to be_assistant }
      it { is_expected.not_to be_system }
    end

    context 'when role is assistant' do
      let(:data) { super().merge(role: 'assistant') }

      it { is_expected.not_to be_user }
      it { is_expected.to be_assistant }
      it { is_expected.not_to be_system }
    end

    context 'when role is system' do
      let(:data) { super().merge(role: 'system') }

      it { is_expected.not_to be_user }
      it { is_expected.not_to be_assistant }
      it { is_expected.to be_system }
    end
  end
end
