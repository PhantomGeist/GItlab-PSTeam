# frozen_string_literal: true

module Geo
  class ProjectSyncWorker
    include ApplicationWorker
    include GeoQueue

    # Do not enqueue another instance of this Worker with the same args
    # if one is currently enqueued or executing. If deduplication occurs,
    # then reschedule the job once after the first job finishes, to
    # ensure all changes get replicated.
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    idempotent!

    data_consistency :always

    sidekiq_options retry: 1, dead: false

    sidekiq_retry_in { |count| 30 * count }

    sidekiq_retries_exhausted do |msg, _|
      Sidekiq.logger.warn "Failed #{msg['class']} with #{msg['args']}: #{msg['error_message']}"
    end

    loggable_arguments 1

    def perform(project_id, options = {}); end
  end
end
