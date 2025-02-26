# frozen_string_literal: true

module Mutations
  module AuditEvents
    module AmazonS3Configurations
      class Update < Base
        graphql_name 'AuditEventsAmazonS3ConfigurationUpdate'

        include ::Audit::Changes

        UPDATE_EVENT_NAME = 'amazon_s3_configuration_updated'
        AUDIT_EVENT_COLUMNS = [:access_key_xid, :secret_access_key, :bucket_name, :aws_region, :name].freeze

        argument :id, ::Types::GlobalIDType[::AuditEvents::AmazonS3Configuration],
          required: true,
          description: 'ID of the Amazon S3 configuration to update.'

        argument :name, GraphQL::Types::String,
          required: false,
          description: 'Destination name.'

        argument :access_key_xid, GraphQL::Types::String,
          required: false,
          description: 'Access key ID of the Amazon S3 account.'

        argument :secret_access_key, GraphQL::Types::String,
          required: false,
          description: 'Secret access key of the Amazon S3 account.'

        argument :bucket_name, GraphQL::Types::String,
          required: false,
          description: 'Name of the bucket where the audit events would be logged.'

        argument :aws_region, GraphQL::Types::String,
          required: false,
          description: 'AWS region where the bucket is created.'

        field :amazon_s3_configuration, ::Types::AuditEvents::AmazonS3ConfigurationType,
          null: true,
          description: 'Updated Amazon S3 configuration.'

        def resolve(id:, access_key_xid: nil, secret_access_key: nil, bucket_name: nil, aws_region: nil, name: nil)
          config = authorized_find!(id)
          config_attributes = {
            access_key_xid: access_key_xid,
            secret_access_key: secret_access_key,
            bucket_name: bucket_name,
            aws_region: aws_region,
            name: name
          }.compact

          if config.update(config_attributes)
            audit_update(config)
            { amazon_s3_configuration: config, errors: [] }
          else
            { amazon_s3_configuration: nil, errors: Array(config.errors) }
          end
        end

        private

        def audit_update(config)
          AUDIT_EVENT_COLUMNS.each do |column|
            audit_changes(
              column,
              as: column.to_s,
              entity: config.group,
              model: config,
              event_type: UPDATE_EVENT_NAME
            )
          end
        end
      end
    end
  end
end
