# frozen_string_literal: true

module Mutations
  module AuditEvents
    module AmazonS3Configurations
      class Delete < Base
        graphql_name 'AuditEventsAmazonS3ConfigurationDelete'

        argument :id, ::Types::GlobalIDType[::AuditEvents::AmazonS3Configuration],
          required: true,
          description: 'ID of the Amazon S3 configuration to destroy.'

        def resolve(id:)
          config = authorized_find!(id)

          audit(config, action: :deleted) if config.destroy
          { errors: Array(config.errors) }
        end
      end
    end
  end
end
