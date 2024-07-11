# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update Amazon S3 configuration', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be_with_reload(:config) { create(:amazon_s3_configuration) }
  let_it_be(:group) { config.group }
  # let_it_be(:owner) { create(:user) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:updated_access_key_xid) { 'AKIA1234RANDOM5678' }
  let_it_be(:updated_secret_access_key) { 'TEST/SECRET/XYZ/PQR' }
  let_it_be(:updated_bucket_name) { 'test-rspec-bucket' }
  let_it_be(:updated_aws_region) { 'us-east-2' }
  let_it_be(:updated_destination_name) { 'updated_destination_name' }
  let_it_be(:config_gid) { global_id_of(config) }

  let(:mutation) { graphql_mutation(:audit_events_amazon_s3_configuration_update, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_amazon_s3_configuration_update) }

  let(:input) do
    {
      id: config_gid,
      accessKeyXid: updated_access_key_xid,
      secretAccessKey: updated_secret_access_key,
      bucketName: updated_bucket_name,
      awsRegion: updated_aws_region,
      name: updated_destination_name
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'a mutation that does not update the configuration' do
    it 'does not update the configuration' do
      expect { mutate }.not_to change { config.reload.attributes }
    end

    it 'does not create audit event' do
      expect { mutate }.not_to change { AuditEvent.count }
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before_all do
        group.add_owner(current_user)
      end

      it 'updates the configuration' do
        mutate

        config.reload

        expect(config.access_key_xid).to eq(updated_access_key_xid)
        expect(config.secret_access_key).to eq(updated_secret_access_key)
        expect(config.bucket_name).to eq(updated_bucket_name)
        expect(config.aws_region).to eq(updated_aws_region)
        expect(config.name).to eq(updated_destination_name)
      end

      it 'audits the update' do
        Mutations::AuditEvents::AmazonS3Configurations::Update::AUDIT_EVENT_COLUMNS.each do |column|
          message = if column == :secret_access_key
                      "Changed #{column}"
                    else
                      "Changed #{column} from #{config[column]} to #{input[column.to_s.camelize(:lower).to_sym]}"
                    end

          expected_hash = {
            name: Mutations::AuditEvents::AmazonS3Configurations::Update::UPDATE_EVENT_NAME,
            author: current_user,
            scope: group,
            target: config,
            message: message
          }

          expect(Gitlab::Audit::Auditor).to receive(:audit).once.ordered.with(hash_including(expected_hash))
        end

        subject
      end

      context 'when the fields are updated with existing values' do
        let(:input) do
          {
            id: config_gid,
            accessKeyXid: config.access_key_xid,
            name: config.name
          }
        end

        it 'does not audit the event' do
          expect(Gitlab::Audit::Auditor).not_to receive(:audit)

          subject
        end
      end

      context 'when no fields are provided for update' do
        let(:input) do
          {
            id: config_gid
          }
        end

        it_behaves_like 'a mutation that does not update the configuration'
      end

      context 'when there is error while updating' do
        before do
          allow_next_instance_of(Mutations::AuditEvents::AmazonS3Configurations::Update) do |mutation|
            allow(mutation).to receive(:authorized_find!).with(config_gid).and_return(config)
          end

          allow(config).to receive(:update).and_return(false)

          errors = ActiveModel::Errors.new(config).tap { |e| e.add(:base, 'error message') }
          allow(config).to receive(:errors).and_return(errors)
        end

        it 'does not update the configuration and returns the error' do
          mutate

          expect(mutation_response).to include(
            'amazonS3Configuration' => nil,
            'errors' => ['error message']
          )
        end
      end
    end

    context 'when current user is a group maintainer' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update the configuration'
    end

    context 'when current user is a group developer' do
      before_all do
        group.add_developer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update the configuration'
    end

    context 'when current user is a group guest' do
      before_all do
        group.add_guest(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update the configuration'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
    it_behaves_like 'a mutation that does not update the configuration'
  end
end
