# frozen_string_literal: true

module Elastic
  class MigrationWorker
    include ApplicationWorker

    data_consistency :always

    include Gitlab::ExclusiveLeaseHelpers
    # There is no onward scheduling and this cron handles work from across the
    # application, so there's no useful context to add.
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext
    include ActionView::Helpers::NumberHelper

    feature_category :global_search
    idempotent!
    urgency :low

    LOCK_TIMEOUT = 30.minutes
    LOCK_SLEEP_SEC = 2
    LOCK_RETRIES = 10

    def perform
      return false unless preflight_check_successful?

      in_lock(self.class.name.underscore, ttl: LOCK_TIMEOUT, retries: LOCK_RETRIES, sleep_sec: LOCK_SLEEP_SEC) do
        # migration index should be checked before pulling the current_migration because if no migrations_index exists,
        # current_migration will return nil
        create_migrations_index_if_not_exists

        migration = Elastic::MigrationRecord.current_migration

        unless migration
          log message: 'MigrationWorker: no migration available'
          break false
        end

        if migration.halted?
          error message: "MigrationWorker: migration[#{migration.name}] has been halted. All future migrations will be halted because of that. Exiting"
          unpause_indexing!(migration)

          break false
        end

        if !migration.started? && migration.space_requirements?
          free_size_bytes = helper.cluster_free_size_bytes
          space_required_bytes = migration.space_required_bytes
          log message: "MigrationWorker: migration[#{migration.name}] checking free space in cluster. Required space #{number_to_human_size(space_required_bytes)}. Free space #{number_to_human_size(free_size_bytes)}."

          if free_size_bytes < space_required_bytes
            warn message: "MigrationWorker: migration[#{migration.name}] You should have at least #{number_to_human_size(space_required_bytes)} of free space in the cluster to run this migration. Please increase the storage in your Elasticsearch cluster."
            log message: "MigrationWorker: migration[#{migration.name}] updating with halted: true"
            migration.halt

            break false
          end
        end

        execute_migration(migration)

        completed = check_and_save_completed_status(migration)

        unpause_indexing!(migration) if completed

        Elastic::DataMigrationService.drop_migration_has_finished_cache!(migration)

        enqueue_next_batch(migration)
      end
    rescue StandardError => e
      error message: "#{self.class.name}: #{e.class} #{e.message}", backtrace: e.backtrace.join("\n")
    end

    private

    def log(...)
      logger.info(structured_payload(...))
    end

    def warn(...)
      logger.warn(structured_payload(...))
    end

    def error(...)
      logger.error(structured_payload(...))
    end

    def preflight_check_successful?
      return false if Feature.disabled?(:elastic_migration_worker, type: :ops)
      return false unless Gitlab::CurrentSettings.elasticsearch_indexing?
      return false unless helper.alias_exists?
      return false if Elastic::ReindexingTask.current

      if helper.unsupported_version?
        log message: 'MigrationWorker: You are using an unsupported version of Elasticsearch. Indexing will be paused to prevent data loss'
        Gitlab::CurrentSettings.update!(elasticsearch_pause_indexing: true)

        return false
      end

      unless Search::ClusterHealthCheck::Elastic.healthy?
        error message: "Advanced search cluster is unhealthy. Execution is skipped."
        return false
      end

      true
    end

    def execute_migration(migration)
      if migration.started? && !migration.batched? && !migration.retry_on_failure?
        log message: "MigrationWorker: migration[#{migration.name}] did not execute migrate method since it was already executed. Waiting for migration to complete"

        return
      end

      pause_indexing!(migration)

      log message: "MigrationWorker: migration[#{migration.name}] executing migrate method"
      migration.migrate
    rescue StandardError => e
      retry_migration(migration, e) if migration.retry_on_failure?

      raise e
    end

    def retry_migration(migration, exception)
      if migration.current_attempt >= migration.max_attempts
        message = "MigrationWorker: migration has failed with #{exception.class}:#{exception.message}, no retries left"
        error message: message, backtrace: exception.backtrace.join("\n")

        migration.fail(message: message)
      else
        log message: "MigrationWorker: increasing previous_attempts to #{migration.current_attempt}"
        migration.save_state!(previous_attempts: migration.current_attempt)
      end
    end

    def enqueue_next_batch(migration)
      return unless migration.batched? && !migration.completed?

      log message: "MigrationWorker: migration[#{migration.name}] kicking off next migration batch"
      Elastic::MigrationWorker.perform_in(migration.throttle_delay)
    end

    def check_and_save_completed_status(migration)
      migration.completed?.tap do |status|
        log message: "MigrationWorker: migration[#{migration.name}] updating with completed: #{status}"
        migration.save!(completed: status)
      end
    end

    def pause_indexing!(migration)
      return unless migration.pause_indexing?
      return if migration.load_state[:pause_indexing].present?

      pause_indexing = !Gitlab::CurrentSettings.elasticsearch_pause_indexing?
      migration.save_state!(pause_indexing: pause_indexing)

      if pause_indexing
        log message: 'MigrationWorker: Pausing indexing'
        Gitlab::CurrentSettings.update!(elasticsearch_pause_indexing: true)
      end
    end

    def unpause_indexing!(migration)
      return unless migration.pause_indexing?
      return unless migration.load_state[:pause_indexing]
      return if migration.load_state[:halted_indexing_unpaused]

      log message: 'MigrationWorker: unpausing indexing'
      Gitlab::CurrentSettings.update!(elasticsearch_pause_indexing: false)

      migration.save_state!(halted_indexing_unpaused: true) if migration.halted?
    end

    def create_migrations_index_if_not_exists
      return if helper.migrations_index_exists?

      log message: 'MigrationWorker: creating migrations index'
      helper.create_migrations_index
    end

    def helper
      Gitlab::Elastic::Helper.default
    end

    def logger
      @logger ||= ::Gitlab::Elasticsearch::Logger.build
    end
  end
end
