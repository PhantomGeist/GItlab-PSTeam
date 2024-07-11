# frozen_string_literal: true

module EE
  module WorkItems
    module RelatedWorkItemLink
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :validate_related_link_restrictions
      def validate_related_link_restrictions
        return super if link_type == ::IssuableLink::TYPE_RELATES_TO

        restriction = find_restriction(source.work_item_type_id, target.work_item_type_id)
        return if restriction.present?

        errors.add :source, format(
          s_('%{source_type} cannot block %{type_type}'),
          source_type: source.work_item_type.name.downcase.pluralize,
          type_type: target.work_item_type.name.downcase.pluralize
        )
      end
    end
  end
end
