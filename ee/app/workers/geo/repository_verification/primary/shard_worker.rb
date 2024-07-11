# frozen_string_literal: true

module Geo
  module RepositoryVerification
    module Primary
      class ShardWorker < Geo::Scheduler::Primary::SchedulerWorker # rubocop:disable Scalability/IdempotentWorker
        loggable_arguments 0

        def perform(shard_name); end
      end
    end
  end
end
