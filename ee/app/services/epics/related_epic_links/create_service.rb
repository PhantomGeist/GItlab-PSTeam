# frozen_string_literal: true

module Epics
  module RelatedEpicLinks
    class CreateService < IssuableLinks::CreateService
      include UsageDataHelper

      def execute
        unless can?(current_user, :admin_epic_link_relation, issuable)
          return error(issuables_no_permission_error_message, 403)
        end

        super
      end

      def linkable_issuables(epics)
        @linkable_issuables ||= epics.select { |epic| can?(current_user, :read_epic_link_relation, epic) }
      end

      def previous_related_issuables
        @related_epics ||= issuable.related_epics(current_user).to_a
      end

      private

      def after_create_for(link)
        track_related_epics_event_for(link_type: params[:link_type], event_type: :added, namespace: issuable.group)
      end

      def references(extractor)
        extractor.epics
      end

      def extractor_context
        { group: issuable.group }
      end

      def target_issuable_type
        :epic
      end

      def link_class
        Epic::RelatedEpicLink
      end

      def issuables_no_permission_error_message
        _("Couldn't link epics. You must have at least the Guest role in the epic's group.")
      end
    end
  end
end
