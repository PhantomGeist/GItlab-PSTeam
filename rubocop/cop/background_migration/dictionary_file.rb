# frozen_string_literal: true

require_relative '../../migration_helpers'
require_relative '../../batched_background_migrations_dictionary'

module RuboCop
  module Cop
    module BackgroundMigration
      # Checks the batched background migration has the corresponding dictionary file
      class DictionaryFile < RuboCop::Cop::Base
        include MigrationHelpers

        MSG = {
          missing_key: "Mandatory key '%{key}' is missing from the dictionary. Please add with an appropriate value.",
          missing_dictionary: <<-MESSAGE.delete("\n").squeeze(' ').strip
            Missing %{file_name}.
            Use the generator 'batched_background_migration' to create dictionary files automatically.
            For more details refer: https://docs.gitlab.com/ee/development/database/batched_background_migrations.html#generator
          MESSAGE
        }.freeze

        DICTIONARY_DIR = "db/docs/batched_background_migrations"

        def_node_matcher :batched_background_migration_name_node, <<~PATTERN
          `(send nil? :queue_batched_background_migration $_ ...)
        PATTERN

        def_node_matcher :migration_constant_value, <<~PATTERN
          `(casgn nil? %const_name ({sym|str} $_))
        PATTERN

        def on_class(node)
          return unless time_enforced?(node) && in_post_deployment_migration?(node)

          migration_name_node = batched_background_migration_name_node(node)
          return unless migration_name_node

          migration_name = if migration_name_node.const_name.present?
                             migration_constant_value(node, const_name: migration_name_node.const_name.to_sym)
                           else
                             migration_name_node.value
                           end

          error_code, msg_params = validate_dictionary_file(migration_name, node)
          return unless error_code.present?

          add_offense(node, message: format(MSG[error_code], msg_params))
        end

        private

        def dictionary_file?(migration_class_name)
          File.exist?(dictionary_file_path(migration_class_name))
        end

        def dictionary_file_path(migration_class_name)
          File.join(rails_root, DICTIONARY_DIR, "#{migration_class_name.underscore}.yml")
        end

        def validate_dictionary_file(migration_name, node)
          unless dictionary_file?(migration_name)
            return [:missing_dictionary, { file_name: dictionary_file_path(migration_name) }]
          end

          bbm_dictionary = RuboCop::BatchedBackgroundMigrationsDictionary.new(version(node))

          return [:missing_key, { key: :finalize_after }] unless bbm_dictionary.finalize_after.present?

          return [:missing_key, { key: :introduced_by_url }] unless bbm_dictionary.introduced_by_url.present?
        end

        def rails_root
          @rails_root ||= File.expand_path('../../..', __dir__)
        end
      end
    end
  end
end
