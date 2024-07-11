# frozen_string_literal: true

module Geo
  class RepositoryShardSyncWorker < Geo::Scheduler::Secondary::SchedulerWorker # rubocop:disable Scalability/IdempotentWorker
    sidekiq_options retry: false
    loggable_arguments 0

    def perform(shard_name); end
  end
end
