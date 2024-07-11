# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Strategies::AmazonS3DestinationStrategy, feature_category: :audit_events do
  let_it_be(:group) { create(:group) }
  let_it_be(:event) { create(:audit_event, :group_event, target_group: group) }

  let_it_be(:event_type) { 'project_name_updated' }
  let_it_be(:request_body) { { key: "value", id: event.id }.to_json }

  describe '#streamable?' do
    subject { described_class.new(event_type, event).streamable? }

    context 'when feature flag is disabled' do
      before do
        stub_licensed_features(external_audit_events: true)
        stub_feature_flags(allow_streaming_audit_events_to_amazon_s3: false)
      end

      context 'when Amazon S3 configurations exists for the group' do
        before do
          create(:amazon_s3_configuration, group: group)
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(allow_streaming_audit_events_to_amazon_s3: true)
      end

      context 'when feature is not licensed' do
        it { is_expected.to be_falsey }
      end

      context 'when feature is licensed' do
        before do
          stub_licensed_features(external_audit_events: true)
        end

        context 'when event group is nil' do
          let_it_be(:event) { build(:audit_event) }

          it { is_expected.to be_falsey }
        end

        context 'when Amazon S3 configurations does not exist for the group' do
          it { is_expected.to be_falsey }
        end

        context 'when Amazon S3 configurations exists for the group' do
          before do
            create(:amazon_s3_configuration, group: group)
          end

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#destinations' do
    subject { described_class.new(event_type, event).send(:destinations) }

    context 'when event group is nil' do
      let_it_be(:event) { build(:audit_event) }

      it 'returns empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when Amazon S3 configurations exist for the group' do
      it 'returns all the destinations' do
        destination1 = create(:amazon_s3_configuration, group: group)
        destination2 = create(:amazon_s3_configuration, group: group)

        expect(subject).to match_array([destination1, destination2])
      end
    end
  end

  describe '#track_and_stream' do
    let(:instance) { described_class.new(event_type, event) }
    let!(:destination) { create(:amazon_s3_configuration, group: group) }

    subject(:track_and_stream) { instance.send(:track_and_stream, destination) }

    context 'when Amazon S3 configuration exists' do
      before do
        allow(instance).to receive(:request_body).and_return(request_body)
      end

      it 'tracks audit event count and calls Aws::S3::Client', :freeze_time do
        time_in_ms = (Time.now.to_f * 1000).to_i
        date = Date.current.strftime("%Y/%m")

        expect(instance).to receive(:track_audit_event_count)

        allow_next_instance_of(Aws::S3::Client) do |s3_client|
          expect(s3_client).to receive(:put_object).with(
            {
              key: "#{event['entity_type']}/#{date}/project_name_updated_#{event['id']}_#{time_in_ms}.json",
              bucket: destination.bucket_name,
              content_type: 'application/json',
              body: request_body
            }
          )
        end

        track_and_stream
      end
    end
  end
end
