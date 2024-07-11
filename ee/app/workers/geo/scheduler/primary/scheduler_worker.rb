# frozen_string_literal: true

module Geo
  module Scheduler
    module Primary
      class SchedulerWorker < Geo::Scheduler::SchedulerWorker # rubocop:disable Scalability/IdempotentWorker
      end
    end
  end
end
