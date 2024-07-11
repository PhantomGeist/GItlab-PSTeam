# frozen_string_literal: true

module Geo
  module RepositoryVerification
    module Secondary
      class ShardWorker < Geo::Scheduler::Secondary::SchedulerWorker # rubocop:disable Scalability/IdempotentWorker
        # rubocop:disable Scalability/CronWorkerContext
        # This worker does not perform work scoped to a context
        include CronjobQueue
        # rubocop:enable Scalability/CronWorkerContext

        loggable_arguments 0

        def perform(shard_name); end
      end
    end
  end
end
