# frozen_string_literal: true

module PackageMetadata
  class SyncWorker
    include ApplicationWorker
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext
    include ExclusiveLeaseGuard

    LEASE_TIMEOUT = 5.minutes

    data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency
    feature_category :software_composition_analysis
    urgency :low

    idempotent!
    sidekiq_options retry: false
    worker_has_external_dependencies!

    # Functionality extracted to PackageMetadata::LicensesSyncWorker and to be removed in subsequent release:
    # https://gitlab.com/gitlab-org/gitlab/-/issues/417692
    def perform; end
  end
end
