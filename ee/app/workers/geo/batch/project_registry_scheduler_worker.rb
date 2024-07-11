# frozen_string_literal: true

module Geo
  module Batch
    # Responsible for scheduling multiple jobs to mark Project Registries as requiring syncing or verification.
    #
    # This class includes an Exclusive Lease guard and only one can be executed at the same time
    # If multiple jobs are scheduled, only one will run and the others will drop forever.
    class ProjectRegistrySchedulerWorker # rubocop:disable Scalability/IdempotentWorker
      include ApplicationWorker

      data_consistency :always

      sidekiq_options retry: 3
      include GeoQueue

      loggable_arguments 0

      def perform(operation); end
    end
  end
end
