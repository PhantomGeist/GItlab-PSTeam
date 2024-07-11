# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphqlTriggers, feature_category: :shared do
  describe '.issuable_weight_updated' do
    let_it_be(:work_item) { create(:work_item) }

    it 'triggers the issuable_weight_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :issuable_weight_updated,
        { issuable_id: work_item.to_gid },
        work_item
      ).and_call_original

      ::GraphqlTriggers.issuable_weight_updated(work_item)
    end

    it 'triggers the issuable_iteration_updated subscription' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :issuable_iteration_updated,
        { issuable_id: work_item.to_gid },
        work_item
      ).and_call_original

      ::GraphqlTriggers.issuable_iteration_updated(work_item)
    end

    describe '.issuable_health_status_updated' do
      it 'triggers the issuable_health_status_updated subscription' do
        expect(GitlabSchema.subscriptions).to receive(:trigger).with(
          :issuable_health_status_updated,
          { issuable_id: work_item.to_gid },
          work_item
        ).and_call_original

        ::GraphqlTriggers.issuable_health_status_updated(work_item)
      end
    end

    describe '.issuable_epic_updated' do
      it 'triggers the issuable_epic_updated subscription' do
        expect(GitlabSchema.subscriptions).to receive(:trigger).with(
          :issuable_epic_updated,
          { issuable_id: work_item.to_gid },
          work_item
        )

        ::GraphqlTriggers.issuable_epic_updated(work_item)
      end
    end
  end

  describe '.ai_completion_response' do
    let_it_be(:user) { create(:user) }
    let(:message) { build(:ai_message, user: user, resource: user) }

    subject { described_class.ai_completion_response(message) }

    before do
      allow(GitlabSchema.subscriptions).to receive(:trigger).and_call_original
    end

    it 'triggers ai_completion_response with subscription arguments' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :ai_completion_response,
        { user_id: message.user.to_gid, ai_action: message.ai_action.to_s },
        message.to_h
      ).and_call_original

      subject
    end

    it 'triggers duplicated ai_completion_response with resource argument' do
      expect(GitlabSchema.subscriptions).to receive(:trigger).with(
        :ai_completion_response,
        { user_id: message.user.to_gid, resource_id: message.resource&.to_gid },
        message.to_h
      ).and_call_original

      subject
    end

    context 'with client_subscription_id' do
      let(:message) { build(:ai_message, user: user, resource: user, role: role, client_subscription_id: 'foo') }
      let(:role) { 'assistant' }

      it 'triggers ai_completion_response with client subscription id' do
        expect(GitlabSchema.subscriptions).to receive(:trigger).with(
          :ai_completion_response,
          {
            user_id: message.user.to_gid,
            ai_action: message.ai_action.to_s,
            client_subscription_id: message.client_subscription_id
          },
          message.to_h
        ).and_call_original

        subject
      end

      context 'for user messages' do
        let(:role) { 'user' }

        it 'triggers ai_completion_response without client subscription id' do
          expect(GitlabSchema.subscriptions).to receive(:trigger).with(
            :ai_completion_response,
            {
              user_id: message.user.to_gid,
              ai_action: message.ai_action.to_s
            },
            message.to_h
          ).and_call_original

          subject
        end
      end
    end
  end
end
