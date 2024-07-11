# frozen_string_literal: true

module Geo
  class RepositorySyncWorker < Geo::Scheduler::Secondary::PerShardSchedulerWorker # rubocop:disable Scalability/IdempotentWorker
    def schedule_job(shard_name); end
  end
end
