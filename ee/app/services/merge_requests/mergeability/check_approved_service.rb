# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckApprovedService < CheckBaseService
      def self.failure_reason
        :not_approved
      end

      def execute
        return inactive unless merge_request.approval_feature_available?

        if merge_request.approved? && !merge_request.approval_state.temporarily_unapproved?
          success
        else
          failure(reason: failure_reason)
        end
      end

      def skip?
        params[:skip_approved_check].present?
      end

      def cacheable?
        false
      end
    end
  end
end
