# frozen_string_literal: true

module AuditEvents
  module Strategies
    class AmazonS3DestinationStrategy < ExternalDestinationStrategy
      def streamable?
        return false unless Feature.enabled?(:allow_streaming_audit_events_to_amazon_s3, audit_event.root_group_entity)

        group = audit_event.root_group_entity
        return false if group.nil?
        return false unless group.licensed_feature_available?(:external_audit_events)

        group.amazon_s3_configurations.exists?
      end

      private

      def destinations
        group = audit_event.root_group_entity
        group.present? ? group.amazon_s3_configurations.to_a : []
      end

      def track_and_stream(destination)
        return unless Feature.enabled?(:allow_streaming_audit_events_to_amazon_s3, audit_event.root_group_entity)

        track_audit_event_count

        payload = request_body
        Aws::S3Client.new(destination.access_key_xid, destination.secret_access_key, destination.aws_region)
          .upload_object(filename(payload), destination.bucket_name, payload, 'application/json')
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e)
      end

      # Returns the name of the json file to be saved in the S3 bucket
      # Eg: Group/2023/09/update_approval_rules_887_1694441509820.json
      def filename(payload)
        "#{audit_event['entity_type']}/#{current_year_and_month}/#{audit_operation}_" \
          "#{::Gitlab::Json.parse(payload)['id']}_#{time_in_ms}.json"
      end

      def time_in_ms
        (Time.now.to_f * 1000).to_i
      end

      # @return [String] Eg: "2023/09"
      def current_year_and_month
        Date.current.strftime("%Y/%m")
      end
    end
  end
end
