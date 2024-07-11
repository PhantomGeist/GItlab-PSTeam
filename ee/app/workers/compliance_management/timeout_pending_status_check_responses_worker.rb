# frozen_string_literal: true

module ComplianceManagement
  class TimeoutPendingStatusCheckResponsesWorker
    include ApplicationWorker

    # This worker does not schedule other workers that require context.
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext

    idempotent!
    feature_category :compliance_management
    data_consistency :sticky

    TIMEOUT_INTERVAL = 2.minutes.ago

    def perform
      return unless Feature.enabled?(:timeout_status_check_responses)

      ::MergeRequests::StatusCheckResponse.pending.each_batch do |batch|
        batch.timeout_eligible.each(&:failed!)
      end
    end
  end
end
