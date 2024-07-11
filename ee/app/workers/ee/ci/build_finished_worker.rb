# frozen_string_literal: true

module EE
  module Ci
    module BuildFinishedWorker
      def process_build(build)
        # Always run `super` first since it contains sync operations.
        # Failing to run sync operations would cause the worker to retry
        # and enqueueing duplicate jobs.
        super

        if requirements_available?(build) && !test_report_already_generated?(build)
          RequirementsManagement::ProcessRequirementsReportsWorker.perform_async(build.id)
        end

        if ::Gitlab.com? && build.has_security_reports?
          ::Security::TrackSecureScansWorker.perform_async(build.id)
        end

        ::Ci::InstanceRunnerFailedJobs.track(build) if build.failed?

        if build.is_a?(::Ci::Build) && build.finished_at.present? && generate_finished_builds_sync_events?
          ::Ci::FinishedBuildChSyncEvent.new(build_id: build.id, build_finished_at: build.finished_at).save
        end
      end

      private

      def test_report_already_generated?(build)
        RequirementsManagement::TestReport.for_user_build(build.user_id, build.id).exists?
      end

      def requirements_available?(build)
        build.project.feature_available?(:requirements, build.user) &&
          !build.project.requirements.empty? &&
          Ability.allowed?(build.user, :create_requirement_test_report, build.project)
      end

      def generate_finished_builds_sync_events?
        ::Feature.enabled?(:ci_data_ingestion_to_click_house) &&
          ::License.feature_available?(:runner_performance_insights)
      end
    end
  end
end
