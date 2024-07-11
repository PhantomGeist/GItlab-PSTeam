# frozen_string_literal: true

module Geo
  module RepositoryVerification
    module Primary
      class BatchWorker < Geo::Scheduler::Primary::PerShardSchedulerWorker # rubocop:disable Scalability/IdempotentWorker
      end
    end
  end
end
