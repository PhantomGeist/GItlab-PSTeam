# frozen_string_literal: true

module Dependencies
  module ExportSerializers
    class GroupDependenciesService
      def self.execute(dependency_list_export)
        new(dependency_list_export).execute
      end

      def initialize(dependency_list_export)
        @dependency_list_export = dependency_list_export
      end

      def execute
        [].tap do |list|
          group_dependencies.in_batches do |batch|  # rubocop: disable Cop/InBatches
            list.concat(build_list_for(batch))
          end
        end
      end

      private

      attr_reader :dependency_list_export

      delegate :group, to: :dependency_list_export, private: true

      def build_list_for(batch)
        batch.with_source.with_version.map do |occurrence|
          {
            name: occurrence.component_name,
            packager: occurrence.package_manager,
            version: occurrence.version,
            licenses: occurrence.licenses,
            location: occurrence.location
          }
        end
      end

      def group_dependencies
        group.sbom_occurrences(with_totals: false).order_by_id
      end
    end
  end
end
