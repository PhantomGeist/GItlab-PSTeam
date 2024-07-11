# frozen_string_literal: true

module Geo
  module RepositoryVerification
    module Secondary
      class SchedulerWorker < Geo::Scheduler::Secondary::PerShardSchedulerWorker # rubocop:disable Scalability/IdempotentWorker
      end
    end
  end
end
