# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Llm::GraphqlSubscriptionResponseService, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let(:response_body) { 'Some response' }
  let(:client_subscription_id) { nil }
  let(:ai_action) { nil }

  let(:options) do
    {
      request_id: 'uuid',
      client_subscription_id: client_subscription_id,
      ai_action: ai_action
    }
  end

  let(:ai_response_json) do
    '{
      "id": "cmpl-72baOZiNHv2njeNoWqPZ12xozfPv7",
      "object": "text_completion",
      "created": 1680855492,
      "model": "text-davinci-003",
      "choices": [
        {
          "text": "Some response",
          "index": 0,
          "logprobs": null,
          "finish_reason": "stop"
        }
      ],
      "usage": {
        "prompt_tokens": 8,
        "completion_tokens": 17,
        "total_tokens": 25
      }
    }'
  end

  let(:response_modifier) { Gitlab::Llm::OpenAi::ResponseModifiers::Completions.new(ai_response_json) }

  describe '#response_message' do
    let(:extras) { { foo: 'bar' } }
    let(:resource) { build_stubbed(:user) }
    let(:uuid) { 'u-u-i-d' }

    subject do
      described_class.new(user, resource, response_modifier, options: options).response_message
    end

    before do
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
      allow(response_modifier).to receive(:extras).and_return(extras)
    end

    it 'is built with proper params', :freeze_time do
      expect(subject).to have_attributes(options.merge(id: uuid,
        content: response_body,
        role: 'assistant',
        timestamp: Time.current,
        errors: [],
        type: nil,
        chunk_id: nil,
        extras: extras,
        user: user,
        resource: resource
      ).compact)
    end
  end

  describe '#execute' do
    let(:service) { described_class.new(user, resource, response_modifier, options: options) }
    let_it_be(:resource) { project }

    subject { service.execute }

    context 'when message is chat' do
      let(:ai_action) { 'chat' }

      it 'saves the message' do
        expect(service.response_message).to receive(:save!)

        subject
      end

      context 'when message is stream chunk' do
        let(:options) { super().merge(chunk_id: 1) }

        it 'does not save the message' do
          expect_next_instance_of(::Gitlab::Llm::AiMessage) do |instance|
            expect(instance).not_to receive(:save!)
          end

          subject
        end
      end

      context 'when message has special type' do
        let(:options) { super().merge(type: 'tool') }

        it 'does not save the message' do
          expect_next_instance_of(::Gitlab::Llm::AiMessage) do |instance|
            expect(instance).not_to receive(:save!)
          end

          subject
        end
      end
    end

    it 'triggers graphql subscription' do
      expect(GraphqlTriggers).to receive(:ai_completion_response).with(service.response_message)

      subject
    end

    it 'does not save the message' do
      expect_next_instance_of(::Gitlab::Llm::AiMessage) do |instance|
        expect(instance).not_to receive(:save!)
      end

      subject
    end

    context 'without user' do
      let(:user) { nil }

      it 'does not broadcast subscription' do
        expect(GraphqlTriggers).not_to receive(:ai_completion_response)

        subject
      end
    end
  end
end
