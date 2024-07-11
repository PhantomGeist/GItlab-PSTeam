# frozen_string_literal: true

module Vulnerabilities
  # rubocop:disable Scalability/IdempotentWorker
  class MarkDroppedAsResolvedWorker
    include ApplicationWorker

    BATCH_SIZE = 100

    data_consistency :delayed
    idempotent!
    deduplicate :until_executing, including_scheduled: true

    feature_category :static_application_security_testing

    loggable_arguments 1

    def perform(_, dropped_identifier_ids)
      dropped_identifier_ids.each_slice(BATCH_SIZE) do |identifier_ids|
        vulnerability_ids = vulnerability_ids_for(identifier_ids)
        vulnerabilities = resolvable_vulnerabilities(vulnerability_ids)

        resolve_batch(vulnerabilities)
      end
    end

    private

    def vulnerability_ids_for(identifier_ids)
      ::Vulnerabilities::Identifier.id_in(identifier_ids)
                                   .order(:id) # rubocop:disable CodeReuse/ActiveRecord
                                   .select_primary_finding_vulnerability_ids
                                   .map(&:vulnerability_id)
    end

    def resolvable_vulnerabilities(vulnerability_ids)
      return [] unless vulnerability_ids.present?

      ::Vulnerability.with_states(:detected)
                     .with_resolution(true)
                     .by_ids(vulnerability_ids)
    end

    def resolve_batch(vulnerabilities)
      return unless vulnerabilities.present?

      ::Vulnerability.transaction do
        create_state_transitions(vulnerabilities)
        current_time = Time.zone.now

        vulnerabilities.update_all(
          resolved_by_id: Users::Internal.security_bot.id,
          resolved_at: current_time,
          updated_at: current_time,
          state: :resolved)
      end
    end

    def create_state_transitions(vulnerabilities)
      state_transitions = vulnerabilities.find_each.map do |vulnerability|
        create_system_note(vulnerability)
        build_state_transition_for(vulnerability)
      end

      Vulnerabilities::StateTransition.bulk_insert!(state_transitions)
    end

    def create_system_note(vulnerability)
      SystemNoteService.change_vulnerability_state(
        vulnerability,
        Users::Internal.security_bot,
        resolution_comment
      )
    end

    def build_state_transition_for(vulnerability)
      current_time = Time.zone.now

      ::Vulnerabilities::StateTransition.new(
        vulnerability: vulnerability,
        from_state: vulnerability.state,
        to_state: :resolved,
        author_id: Users::Internal.security_bot.id,
        comment: resolution_comment,
        created_at: current_time,
        updated_at: current_time
      )
    end

    def resolution_comment
      # rubocop:disable Gitlab/DocUrl
      _("This vulnerability was automatically resolved because its vulnerability type was disabled in this project " \
        "or removed from GitLab's default ruleset. " \
        "For details about SAST rule changes, " \
        "see https://docs.gitlab.com/ee/user/application_security/sast/rules#important-rule-changes.")
      # rubocop:enable Gitlab/DocUrl
    end
  end
  # rubocop:enable Scalability/IdempotentWorker
end
