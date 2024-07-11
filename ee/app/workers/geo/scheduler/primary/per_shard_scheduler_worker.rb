# frozen_string_literal: true

module Geo
  module Scheduler
    module Primary
      class PerShardSchedulerWorker < Geo::Scheduler::PerShardSchedulerWorker # rubocop:disable Scalability/IdempotentWorker
      end
    end
  end
end
