# frozen_string_literal: true

class GeoRepositoryDestroyWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  data_consistency :always

  sidekiq_options retry: 3
  include GeoQueue

  loggable_arguments 1, 2, 3

  def perform(id, name = nil, disk_path = nil, storage_name = nil); end
end
