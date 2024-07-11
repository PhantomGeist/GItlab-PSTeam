# frozen_string_literal: true

module Geo
  module Scheduler
    module Secondary
      class PerShardSchedulerWorker < Geo::Scheduler::PerShardSchedulerWorker # rubocop:disable Scalability/IdempotentWorker
      end
    end
  end
end
