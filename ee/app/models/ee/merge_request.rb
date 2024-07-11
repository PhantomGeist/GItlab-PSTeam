# frozen_string_literal: true

module EE
  module MergeRequest
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    include ::Gitlab::Allowable
    include ::Gitlab::Utils::StrongMemoize
    include FromUnion

    USES_MERGE_BASE_PIPELINE_FOR_COMPARISON = {
      ::Ci::CompareMetricsReportsService => ->(_project) { true },
      ::Ci::CompareCodequalityReportsService => ->(_project) { true },
      ::Ci::CompareSecurityReportsService => ->(_project) { true }
    }.freeze

    MAX_CHECKED_PIPELINES_FOR_SECURITY_REPORT_COMPARISON = 10

    prepended do
      include Elastic::ApplicationVersionedSearch
      include DeprecatedApprovalsBeforeMerge
      include UsageStatistics
      include IterationEventable

      belongs_to :iteration, foreign_key: 'sprint_id', inverse_of: :merge_requests

      has_many :approvers, as: :target, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent
      has_many :approver_users, through: :approvers, source: :user
      has_many :approver_groups, as: :target, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent
      has_many :status_check_responses, class_name: 'MergeRequests::StatusCheckResponse', inverse_of: :merge_request
      has_many :approval_rules, class_name: 'ApprovalMergeRequestRule', inverse_of: :merge_request do
        def applicable_to_branch(branch)
          ActiveRecord::Associations::Preloader.new(
            records: self,
            associations: [:users, :groups, approval_project_rule: [:users, :groups, :protected_branches]]
          ).call

          self.select do |rule|
            next true unless rule.approval_project_rule.present?
            next true if rule.modified_from_project_rule

            rule.approval_project_rule.applies_to_branch?(branch)
          end
        end
      end
      has_many :approval_merge_request_rule_sources, through: :approval_rules
      has_many :approval_project_rules, through: :approval_merge_request_rule_sources
      has_one :merge_train_car, class_name: 'MergeTrains::Car', inverse_of: :merge_request, dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent

      has_many :blocks_as_blocker,
        class_name: 'MergeRequestBlock',
        inverse_of: :blocking_merge_request,
        foreign_key: :blocking_merge_request_id

      has_many :blocks_as_blockee,
        class_name: 'MergeRequestBlock',
        inverse_of: :blocked_merge_request,
        foreign_key: :blocked_merge_request_id

      has_many :blocking_merge_requests, through: :blocks_as_blockee

      has_many :blocked_merge_requests, through: :blocks_as_blocker

      has_many :compliance_violations, class_name: 'MergeRequests::ComplianceViolation'
      has_many :scan_result_policy_violations, class_name: 'Security::ScanResultPolicyViolation'

      delegate :sha, to: :head_pipeline, prefix: :head_pipeline, allow_nil: true
      delegate :sha, to: :base_pipeline, prefix: :base_pipeline, allow_nil: true
      delegate :wrapped_approval_rules, :invalid_approvers_rules, to: :approval_state

      accepts_nested_attributes_for :approval_rules, allow_destroy: true

      scope :order_review_time_desc, -> do
        joins(:metrics).reorder(::MergeRequest::Metrics.review_time_field.asc.nulls_last)
      end

      scope :with_code_review_api_entity_associations, -> do
        preload(
          :author, :approved_by_users, :metrics,
          latest_merge_request_diff: :merge_request_diff_files, target_project: :namespace, milestone: :project)
      end

      scope :including_merge_train, -> do
        includes(:merge_train_car)
      end

      scope :with_head_pipeline, -> { where.not(head_pipeline_id: nil) }

      scope :for_projects_with_security_policy_project, -> do
        joins('INNER JOIN security_orchestration_policy_configurations ' \
              'ON merge_requests.target_project_id = security_orchestration_policy_configurations.project_id')
      end

      scope :with_applied_scan_result_policies, -> do
        joins(:approval_rules).merge(ApprovalMergeRequestRule.scan_finding)
      end

      after_create_commit :create_pending_status_check_responses, if: :allow_external_status_checks?
      after_update :sync_merge_request_compliance_violation, if: :saved_change_to_title?

      def sync_merge_request_compliance_violation
        compliance_violations.update_all(title: title)
      end

      def create_pending_status_check_responses
        return unless ::Feature.enabled?(:pending_status_check_responses)

        ::ComplianceManagement::PendingStatusCheckWorker.perform_async(id, project.id, target_branch_sha)
      end

      def merge_requests_author_approval?
        !!target_project&.merge_requests_author_approval? &&
          !policy_approval_settings.fetch(:prevent_approval_by_author, false)
      end

      def merge_requests_disable_committers_approval?
        !!target_project&.merge_requests_disable_committers_approval? ||
          policy_approval_settings.fetch(:prevent_approval_by_commit_author, false)
      end

      def require_password_to_approve?
        target_project&.require_password_to_approve? ||
          policy_approval_settings.fetch(:require_password_to_approve, false)
      end

      def policy_approval_settings
        scan_result_policy_violations
          .including_scan_result_policy_reads
          .pluck(:project_approval_settings)
          .reduce({}) { |acc, setting| acc.merge(setting.select { |_, value| value }.symbolize_keys) }
      end
      strong_memoize_attr :policy_approval_settings
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      # This is an ActiveRecord scope in CE
      def with_web_entity_associations
        super.preload(target_project: :invited_groups)
      end

      # This is an ActiveRecord scope in CE
      def with_api_entity_associations
        super.preload(
          :blocking_merge_requests,
          :approval_rules,
          target_project: [:regular_or_any_approver_approval_rules, group: :saml_provider]
        )
      end

      def sort_by_attribute(method, *args, **kwargs)
        if method.to_s == 'review_time_desc'
          order_review_time_desc
        else
          super
        end
      end

      # Includes table keys in group by clause when sorting
      # preventing errors in postgres
      #
      # Returns an array of arel columns
      def grouping_columns(sort)
        grouping_columns = super
        grouping_columns << ::MergeRequest::Metrics.review_time_field if sort.to_s == 'review_time_desc'
        grouping_columns
      end

      # override
      def use_separate_indices?
        true
      end

      override :mergeable_state_checks
      def mergeable_state_checks
        [
          ::MergeRequests::Mergeability::CheckApprovedService,
          ::MergeRequests::Mergeability::CheckDeniedPoliciesService,
          ::MergeRequests::Mergeability::CheckBlockedByOtherMrsService,
          ::MergeRequests::Mergeability::CheckExternalStatusChecksPassedService
        ] + super
      end
    end

    override :predefined_variables
    def predefined_variables
      super.concat(merge_request_approval_variables)
    end

    override :skipped_mergeable_checks
    def skipped_mergeable_checks(options = {})
      skip_additional_checks = options[:auto_merge_strategy] == AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS &&
        ::Feature.enabled?(:additional_merge_when_checks_ready, project)

      super.merge(
        skip_approved_check: options[:auto_merge_strategy] == AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS,
        skip_draft_check: skip_additional_checks,
        skip_blocked_check: skip_additional_checks,
        skip_discussions_check: skip_additional_checks
      )
    end

    override :merge_blocked_by_other_mrs?
    def merge_blocked_by_other_mrs?
      strong_memoize(:merge_blocked_by_other_mrs) do
        blocking_merge_requests_feature_available? &&
          blocking_merge_requests.any? { |mr| !mr.merged? }
      end
    end

    def on_train?
      merge_train_car&.active?
    end

    def allows_multiple_assignees?
      project.feature_available?(:multiple_merge_request_assignees)
    end

    def allows_multiple_reviewers?
      project.feature_available?(:multiple_merge_request_reviewers)
    end

    def allow_external_status_checks?
      project.licensed_feature_available?(:external_status_checks)
    end

    def visible_blocking_merge_requests(user)
      Ability.merge_requests_readable_by_user(blocking_merge_requests, user)
    end

    def visible_blocking_merge_request_refs(user)
      visible_blocking_merge_requests(user).map do |mr|
        mr.to_reference(target_project)
      end
    end

    # Unlike +visible_blocking_merge_requests+, this method doesn't include
    # blocking MRs that have been merged. This simplifies output, since we don't
    # need to tell the user that there are X hidden blocking MRs, of which only
    # Y are an obstacle. Pass include_merged: true to override this behaviour.
    def hidden_blocking_merge_requests_count(user, include_merged: false)
      hidden = blocking_merge_requests - visible_blocking_merge_requests(user)

      hidden.delete_if(&:merged?) unless include_merged

      hidden.count
    end

    def has_denied_policies?
      return false unless license_scanning_feature_available?

      return false unless actual_head_pipeline

      return false unless ::Gitlab::LicenseScanning
        .scanner_for_pipeline(project, actual_head_pipeline)
        .results_available?

      return false if has_approved_license_check?

      report_diff = compare_reports(::Ci::CompareLicenseScanningReportsService)

      licenses = report_diff.dig(:data, 'new_licenses')

      return false if licenses.nil? || licenses.empty?

      licenses.any? do |l|
        status = l.dig('classification', 'approval_status')
        'denied' == status
      end
    end

    def enabled_reports
      {
        sast: report_type_enabled?(:sast),
        container_scanning: report_type_enabled?(:container_scanning),
        dast: report_type_enabled?(:dast),
        dependency_scanning: report_type_enabled?(:dependency_scanning),
        license_scanning: report_type_enabled?(:license_scanning),
        coverage_fuzzing: report_type_enabled?(:coverage_fuzzing),
        secret_detection: report_type_enabled?(:secret_detection),
        api_fuzzing: report_type_enabled?(:api_fuzzing)
      }
    end

    def has_security_reports?
      !!actual_head_pipeline&.complete_and_has_reports?(::Ci::JobArtifact.security_reports)
    end

    def has_dependency_scanning_reports?
      !!actual_head_pipeline&.complete_and_has_reports?(::Ci::JobArtifact.of_report_type(:dependency_list))
    end

    def compare_dependency_scanning_reports(current_user)
      return missing_report_error("dependency scanning") unless has_dependency_scanning_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'dependency_scanning')
    end

    def has_container_scanning_reports?
      !!actual_head_pipeline&.complete_and_has_reports?(::Ci::JobArtifact.of_report_type(:container_scanning))
    end

    def compare_container_scanning_reports(current_user)
      return missing_report_error("container scanning") unless has_container_scanning_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'container_scanning')
    end

    def has_dast_reports?
      !!actual_head_pipeline&.complete_and_has_reports?(::Ci::JobArtifact.of_report_type(:dast))
    end

    def compare_dast_reports(current_user)
      return missing_report_error("DAST") unless has_dast_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'dast')
    end

    def compare_license_scanning_reports(current_user)
      unless ::Gitlab::LicenseScanning.scanner_for_pipeline(project, actual_head_pipeline).results_available?
        return missing_report_error("license scanning")
      end

      compare_reports(::Ci::CompareLicenseScanningReportsService, current_user)
    end

    def compare_license_scanning_reports_collapsed(current_user)
      unless ::Gitlab::LicenseScanning.scanner_for_pipeline(project, actual_head_pipeline).results_available?
        return missing_report_error("license scanning")
      end

      compare_reports(
        ::Ci::CompareLicenseScanningReportsCollapsedService,
        current_user,
        'license_scanning',
        additional_params: { license_check: approval_rules.license_compliance.any? }
      )
    end

    def has_metrics_reports?
      !!actual_head_pipeline&.complete_and_has_reports?(::Ci::JobArtifact.of_report_type(:metrics))
    end

    def compare_metrics_reports
      return missing_report_error("metrics") unless has_metrics_reports?

      compare_reports(::Ci::CompareMetricsReportsService)
    end

    def has_coverage_fuzzing_reports?
      !!actual_head_pipeline&.complete_and_has_reports?(::Ci::JobArtifact.of_report_type(:coverage_fuzzing))
    end

    def compare_coverage_fuzzing_reports(current_user)
      return missing_report_error("coverage fuzzing") unless has_coverage_fuzzing_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'coverage_fuzzing')
    end

    def has_api_fuzzing_reports?
      !!actual_head_pipeline&.complete_and_has_reports?(::Ci::JobArtifact.of_report_type(:api_fuzzing))
    end

    def compare_api_fuzzing_reports(current_user)
      return missing_report_error('api fuzzing') unless has_api_fuzzing_reports?

      compare_reports(::Ci::CompareSecurityReportsService, current_user, 'api_fuzzing')
    end

    override :use_merge_base_pipeline_for_comparison?
    def use_merge_base_pipeline_for_comparison?(service_class)
      !!USES_MERGE_BASE_PIPELINE_FOR_COMPARISON[service_class]&.call(project)
    end

    def synchronize_approval_rules_from_target_project
      return if merged?

      project_rules = target_project.approval_rules.report_approver.includes(:users, :groups)
      project_rules.find_each do |project_rule|
        project_rule.apply_report_approver_rules_to(self)
      end
    end

    def sync_project_approval_rules_for_policy_configuration(configuration_id)
      return if merged?

      project_rules = target_project
        .approval_rules
        .report_approver
        .for_policy_configuration(configuration_id)
        .includes(:users, :groups)

      project_rules.find_each do |project_rule|
        project_rule.apply_report_approver_rules_to(self)
      end
    end

    def reset_required_approvals(approval_rules)
      return if merged?

      approval_rules.filter_map(&:source_rule).map do |rule|
        rule.apply_report_approver_rules_to(self)
      end
    end

    def applicable_approval_rules_for_user(user_id)
      wrapped_approval_rules.select do |rule|
        rule.approvers.pluck(:id).include?(user_id)
      end
    end

    def security_reports_up_to_date?
      project.security_reports_up_to_date_for_ref?(target_branch)
    end

    def audit_details
      title
    end

    def latest_pipeline_for_target_branch
      @latest_pipeline ||= project.ci_pipelines
          .order(id: :desc)
          .find_by(ref: target_branch)
    end

    def latest_finished_target_branch_pipeline_for_scan_result_policy
      @latest_finished_pipeline ||= project
          .all_pipelines
          .ci_and_security_orchestration_sources
          .finished
          .order(id: :desc)
          .find_by(ref: target_branch, tag: false)
    end

    override :can_suggest_reviewers?
    def can_suggest_reviewers?
      open? && modified_paths.any?
    end

    override :suggested_reviewer_users
    def suggested_reviewer_users
      return ::User.none unless predictions && predictions.suggested_reviewers.is_a?(Hash)

      usernames = Array.wrap(suggested_reviewers["reviewers"])
      return ::User.none if usernames.empty?

      # Preserve the original order of suggested usernames
      join_sql = ::MergeRequest.sanitize_sql_array(
        [
          'JOIN UNNEST(ARRAY[?]::varchar[]) WITH ORDINALITY AS t(username, ord) USING(username)',
          usernames
        ]
      )

      project.authorized_users.with_state(:active).human
        .joins(Arel.sql(join_sql))
        .order('t.ord')
    end

    def rebase_commit_is_different?(newrev)
      rebase_commit_sha != newrev
    end

    def diff_llm_summaries
      ::MergeRequest::DiffLlmSummary
        .includes(:user, merge_request_diff: [:merge_request])
        .where(merge_request_diff_id: merge_request_diffs.recent)
        .order(created_at: :desc)
    end

    def merge_train
      target_project.merge_train_for(target_branch)
    end

    override :should_be_rebased?
    def should_be_rebased?
      super && !on_current_ff_train?
    end

    override :comparison_base_pipeline
    def comparison_base_pipeline(service_class)
      return super unless security_comparision?(service_class)

      find_merge_base_pipeline_with_security_reports || find_base_pipeline_with_security_reports
    end

    def blocking_merge_requests_feature_available?
      project.licensed_feature_available?(:blocking_merge_requests)
    end

    def license_scanning_feature_available?
      project.licensed_feature_available?(:license_scanning)
    end

    private

    def security_comparision?(service_class)
      service_class == ::Ci::CompareSecurityReportsService
    end

    def find_merge_base_pipeline_with_security_reports
      last_merge_base_pipelines(limit: MAX_CHECKED_PIPELINES_FOR_SECURITY_REPORT_COMPARISON).find do |pipeline|
        pipeline.self_and_project_descendants.any?(&:has_security_reports?)
      end
    end

    def find_base_pipeline_with_security_reports
      last_base_pipelines(limit: MAX_CHECKED_PIPELINES_FOR_SECURITY_REPORT_COMPARISON).find do |pipeline|
        pipeline.self_and_project_descendants.any?(&:has_security_reports?)
      end
    end

    def last_merge_base_pipelines(limit:)
      merge_base_pipelines.order(id: :desc).limit(limit)
    end

    def last_base_pipelines(limit:)
      base_pipelines.order(id: :desc).limit(limit)
    end

    def on_current_ff_train?
      return false unless on_train? && merge_train_car.pipeline&.sha == merge_params.dig('train_ref', 'commit_sha')

      ::Feature.enabled?(:fast_forward_merge_trains_support, target_project)
    end

    def has_approved_license_check?
      if rule = approval_rules.license_compliance.last
        ApprovalWrappedRule.wrap(self, rule).approved?
      end
    end

    def merge_request_approval_variables
      return unless approval_feature_available?

      strong_memoize(:merge_request_approval_variables) do
        ::Gitlab::Ci::Variables::Collection.new.tap do |variables|
          variables.append(key: 'CI_MERGE_REQUEST_APPROVED', value: approved?.to_s) if approved?
        end
      end
    end
  end
end
