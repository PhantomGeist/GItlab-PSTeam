# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ChatStorage, :clean_gitlab_redis_chat, feature_category: :duo_chat do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:another_user) { build_stubbed(:user) }
  let(:request_id) { 'uuid' }
  let(:timestamp) { Time.current.to_s }
  let(:payload) do
    {
      timestamp: timestamp,
      request_id: request_id,
      errors: ['some error1', 'another error'],
      role: 'user',
      content: 'response',
      user: user
    }
  end

  subject { described_class.new(user) }

  before do
    attributes = payload.except(:user).merge(content: 'other user unrelated cache', user: another_user)
    build(:ai_chat_message, attributes).save!
  end

  describe '#add' do
    let(:message) { build(:ai_chat_message, payload) }

    it 'adds new message', :aggregate_failures do
      uuid = 'unique_id'

      expect(SecureRandom).to receive(:uuid).once.and_return(uuid)
      expect(subject.messages).to be_empty

      subject.add(message)

      last = subject.messages.last
      expect(last.id).to eq(uuid)
      expect(last.user).to eq(user)
      expect(last.request_id).to eq(request_id)
      expect(last.errors).to eq(['some error1', 'another error'])
      expect(last.content).to eq('response')
      expect(last.role).to eq('user')
      expect(last.ai_action).to eq('chat')
      expect(last.timestamp).not_to be_nil
    end

    context 'with MAX_MESSAGES limit' do
      before do
        stub_const('Gitlab::Llm::ChatStorage::MAX_MESSAGES', 2)
      end

      it 'removes oldest messages if we reach maximum message limit' do
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg1')))
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg2')))

        expect(subject.messages.map(&:content)).to eq(%w[msg1 msg2])

        subject.add(build(:ai_chat_message, payload.merge(content: 'msg3')))

        expect(subject.messages.map(&:content)).to eq(%w[msg2 msg3])
      end
    end
  end

  describe '#messages' do
    let(:filters) { {} }

    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg2', role: 'assistant', request_id: '2')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg3', role: 'assistant', request_id: '3')))
    end

    it 'returns all records for this user' do
      expect(subject.messages(filters).map(&:content)).to eq(%w[msg1 msg2 msg3])
    end

    context 'when filtering by role' do
      let(:filters) { { roles: ['user'] } }

      it 'returns only records for this role' do
        expect(subject.messages(filters).map(&:content)).to eq(%w[msg1])
      end
    end

    context 'when filtering by request_ids' do
      let(:filters) { { request_ids: %w[2 3] } }

      it 'returns only records with the same request_id' do
        expect(subject.messages(filters).map(&:content)).to eq(%w[msg2 msg3])
      end
    end
  end

  describe '#last_conversation' do
    context 'when there is no /reset message' do
      before do
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg2', role: 'user', request_id: '3')))
      end

      it 'returns all records for this user' do
        expect(subject.last_conversation.map(&:content)).to eq(%w[msg1 msg2])
      end
    end

    context 'when there is /reset message' do
      before do
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
        subject.add(build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')))
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg3', role: 'user', request_id: '3')))
        subject.add(build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')))
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg5', role: 'user', request_id: '3')))
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg6', role: 'user', request_id: '3')))
      end

      it 'returns all records for this user since last /reset message' do
        expect(subject.last_conversation.map(&:content)).to eq(%w[msg5 msg6])
      end
    end

    context 'when there is /reset message as the last message' do
      before do
        subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
        subject.add(build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')))
      end

      it 'returns all records for this user since last /reset message' do
        expect(subject.last_conversation.map(&:content)).to be_empty
      end
    end
  end
end
