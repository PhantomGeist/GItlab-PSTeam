# frozen_string_literal: true

module Geo
  class RepositoriesCleanUpWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker

    data_consistency :always

    include GeoQueue

    def perform(geo_node_id); end
  end
end
