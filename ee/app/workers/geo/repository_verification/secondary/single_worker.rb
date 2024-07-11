# frozen_string_literal: true

module Geo
  module RepositoryVerification
    module Secondary
      class SingleWorker # rubocop:disable Scalability/IdempotentWorker
        include ApplicationWorker

        data_consistency :always
        include GeoQueue

        sidekiq_options retry: false

        def perform(registry_id); end
      end
    end
  end
end
