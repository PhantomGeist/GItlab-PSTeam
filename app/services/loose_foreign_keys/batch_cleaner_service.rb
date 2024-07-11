# frozen_string_literal: true

module LooseForeignKeys
  class BatchCleanerService
    CLEANUP_ATTEMPTS_BEFORE_RESCHEDULE = 3
    CONSUME_AFTER_RESCHEDULE = 5.minutes

    def initialize(parent_table:, loose_foreign_key_definitions:, deleted_parent_records:, modification_tracker: LooseForeignKeys::ModificationTracker.new)
      @parent_table = parent_table
      @loose_foreign_key_definitions = loose_foreign_key_definitions
      @deleted_parent_records = deleted_parent_records
      @modification_tracker = modification_tracker
      @deleted_records_counter = Gitlab::Metrics.counter(
        :loose_foreign_key_processed_deleted_records,
        'The number of processed loose foreign key deleted records'
      )
      @deleted_records_rescheduled_count = Gitlab::Metrics.counter(
        :loose_foreign_key_rescheduled_deleted_records,
        'The number of rescheduled loose foreign key deleted records'
      )
      @deleted_records_incremented_count = Gitlab::Metrics.counter(
        :loose_foreign_key_incremented_deleted_records,
        'The number of loose foreign key deleted records with incremented cleanup_attempts'
      )
    end

    def execute
      loose_foreign_key_definitions.each do |loose_foreign_key_definition|
        run_cleaner_service(loose_foreign_key_definition, with_skip_locked: true)

        if modification_tracker.over_limit?
          handle_over_limit
          break
        end

        run_cleaner_service(loose_foreign_key_definition, with_skip_locked: false)

        if modification_tracker.over_limit?
          handle_over_limit
          break
        end
      end

      return if modification_tracker.over_limit?

      # At this point, all associations are cleaned up, we can update the status of the parent records
      update_count = LooseForeignKeys::DeletedRecord.mark_records_processed(deleted_parent_records)

      deleted_records_counter.increment({ table: parent_table, db_config_name: db_config_name }, update_count)
    end

    private

    attr_reader :parent_table, :loose_foreign_key_definitions, :deleted_parent_records, :modification_tracker, :deleted_records_counter, :deleted_records_rescheduled_count, :deleted_records_incremented_count

    def handle_over_limit
      records_to_reschedule = []
      records_to_increment = []

      deleted_parent_records.each do |deleted_record|
        if deleted_record.cleanup_attempts >= CLEANUP_ATTEMPTS_BEFORE_RESCHEDULE
          records_to_reschedule << deleted_record
        else
          records_to_increment << deleted_record
        end
      end

      reschedule_count = LooseForeignKeys::DeletedRecord.reschedule(records_to_reschedule, CONSUME_AFTER_RESCHEDULE.from_now)
      deleted_records_rescheduled_count.increment({ table: parent_table, db_config_name: db_config_name }, reschedule_count)

      increment_count = LooseForeignKeys::DeletedRecord.increment_attempts(records_to_increment)
      deleted_records_incremented_count.increment({ table: parent_table, db_config_name: db_config_name }, increment_count)
    end

    def record_result(cleaner, result)
      if cleaner.async_delete?
        modification_tracker.add_deletions(result[:table], result[:affected_rows])
      elsif cleaner.async_nullify?
        modification_tracker.add_updates(result[:table], result[:affected_rows])
      end
    end

    def run_cleaner_service(loose_foreign_key_definition, with_skip_locked:)
      base_models_for_gitlab_schema = Gitlab::Database.schemas_to_base_models.fetch(loose_foreign_key_definition.options[:gitlab_schema])
      base_models_for_gitlab_schema.each do |base_model|
        cleaner = CleanerService.new(
          loose_foreign_key_definition: loose_foreign_key_definition,
          connection: base_model.connection,
          deleted_parent_records: deleted_parent_records,
          with_skip_locked: with_skip_locked
        )

        loop do
          result = cleaner.execute
          record_result(cleaner, result)

          break if modification_tracker.over_limit? || result[:affected_rows] == 0
        end
      end
    end

    def db_config_name
      LooseForeignKeys::DeletedRecord.connection.pool.db_config.name
    end
  end
end
