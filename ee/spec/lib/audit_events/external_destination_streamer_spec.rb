# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::ExternalDestinationStreamer, feature_category: :audit_events do
  before do
    stub_licensed_features(external_audit_events: true)

    allow_next_instance_of(::GoogleCloud::Authentication) do |instance|
      allow(instance).to receive(:generate_access_token).and_return("sample-token")
    end
  end

  describe '#stream_to_destinations' do
    let_it_be(:event) { create(:audit_event, :group_event) }
    let(:group) { event.entity }

    subject { described_class.new('audit_operation', event).stream_to_destinations }

    context 'when no external audit event destinations are present' do
      it 'does not make any HTTP call' do
        expect(Gitlab::HTTP).not_to receive(:post)

        subject
      end
    end

    context 'when external destinations are present' do
      before do
        create(:external_audit_event_destination, group: group)
        create_list(:instance_external_audit_event_destination, 2)
        create(:google_cloud_logging_configuration, group: group)
        create(:instance_google_cloud_logging_configuration)
        create(:amazon_s3_configuration, group: group)
      end

      it 'makes correct number of external calls' do
        expect(Gitlab::HTTP).to receive(:post).exactly(5).times

        expect_next_instance_of(Aws::S3::Client) do |instance|
          expected_body = event.to_json.merge({ event_type: "audit_operation" })
          expect(instance).to receive(:put_object).with(hash_including(body: expected_body))
        end

        subject
      end
    end
  end

  describe '#streamable?' do
    let_it_be(:event) { create(:audit_event, :group_event) }
    let_it_be(:group) { event.entity }

    subject { described_class.new('audit_operation', event).streamable? }

    context 'when none of them is streamable' do
      it { is_expected.to be_falsey }
    end

    context 'when all of them are streamable' do
      before do
        create(:external_audit_event_destination, group: group)
        create(:instance_external_audit_event_destination)
        create(:google_cloud_logging_configuration, group: group)
        create(:instance_google_cloud_logging_configuration)
        create(:amazon_s3_configuration, group: group)
      end

      it { is_expected.to be_truthy }
    end

    context 'when at least one of them is streamable' do
      context 'when only group external destination is streamable' do
        before do
          create(:external_audit_event_destination, group: group)
        end

        it { is_expected.to be_truthy }
      end

      context 'when only instance destination is streamable' do
        before do
          create(:instance_external_audit_event_destination)
        end

        it { is_expected.to be_truthy }
      end

      context 'when only google cloud logging destination is streamable' do
        before do
          create(:google_cloud_logging_configuration, group: group)
        end

        it { is_expected.to be_truthy }
      end

      context 'when only instance google cloud logging destination is streamable' do
        before do
          create(:instance_google_cloud_logging_configuration)
        end

        it { is_expected.to be_truthy }
      end

      context 'when only amazon s3 destination is streamable' do
        before do
          create(:amazon_s3_configuration, group: group)
        end

        it { is_expected.to be_truthy }
      end
    end
  end
end
