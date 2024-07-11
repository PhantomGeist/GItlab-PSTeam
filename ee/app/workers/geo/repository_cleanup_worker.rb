# frozen_string_literal: true

module Geo
  class RepositoryCleanupWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker

    data_consistency :always

    sidekiq_options retry: 3
    include GeoQueue

    loggable_arguments 1, 2, 3

    def perform(project_id, name, disk_path, storage_name); end
  end
end
