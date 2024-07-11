# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckBlockedByOtherMrsService < CheckBaseService
      def self.failure_reason
        :merge_request_blocked
      end

      def execute
        return inactive unless merge_request.blocking_merge_requests_feature_available?

        if merge_request.merge_blocked_by_other_mrs?
          failure(reason: failure_reason)
        else
          success
        end
      end

      def skip?
        params[:skip_blocked_check].present?
      end

      def cacheable?
        false
      end
    end
  end
end
