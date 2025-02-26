# frozen_string_literal: true

class ApprovalProjectRule < ApplicationRecord
  include ApprovalRuleLike
  include Auditable
  extend ::Gitlab::Utils::Override

  UNSUPPORTED_SCANNER = 'cluster_image_scanning'
  SUPPORTED_SCANNERS = (::Ci::JobArtifact::SECURITY_REPORT_FILE_TYPES - [UNSUPPORTED_SCANNER]).freeze
  DEFAULT_SEVERITIES = %w[unknown high critical].freeze
  NEWLY_DETECTED_STATES = { NEWLY_DETECTED.to_sym => 0, NEW_NEEDS_TRIAGE.to_sym => 5, NEW_DISMISSED.to_sym => 6 }.freeze
  APPROVAL_VULNERABILITY_STATES = ::Enums::Vulnerability.vulnerability_states.merge(NEWLY_DETECTED_STATES).freeze
  APPROVAL_PROJECT_RULE_CREATION_EVENT = 'approval_project_rule_created'

  belongs_to :project
  has_and_belongs_to_many :protected_branches
  has_many :approval_merge_request_rule_sources
  has_many :approval_merge_request_rules, through: :approval_merge_request_rule_sources

  # the associations below are needed
  # to export approval rules correctly
  has_many :approval_project_rules_users, class_name: 'ApprovalProjectRulesUser'
  has_many :approval_project_rules_protected_branches, class_name: 'ApprovalProjectRulesProtectedBranch'

  after_initialize :set_scanners_default_value
  after_create_commit :audit_creation, :track_creation_event

  enum rule_type: {
    regular: 0,
    code_owner: 1, # currently unused
    report_approver: 2,
    any_approver: 3
  }

  attribute :severity_levels, default: DEFAULT_SEVERITIES

  scope :not_from_scan_result_policy, -> { where(report_type: nil).or(where.not(report_type: [:scan_finding, :license_scanning])) }
  scope :report_approver_without_scan_finding, -> { report_approver.where.not(report_type: [:scan_finding, :license_scanning]) }
  scope :for_all_branches, -> { where.missing(:protected_branches) }
  scope :for_all_protected_branches, -> { for_all_branches.where(applies_to_all_protected_branches: true) }

  alias_method :code_owner, :code_owner?

  validates :name, uniqueness: { scope: [:project_id, :rule_type] }, unless: :scan_finding?
  validates :name, uniqueness: { scope: [:project_id, :rule_type, :security_orchestration_policy_configuration_id, :orchestration_policy_idx] }, if: :scan_finding?
  validate :validate_security_report_approver_name
  validates :rule_type, uniqueness: { scope: :project_id, message: proc { _('any-approver for the project already exists') } }, if: :any_approver?
  validates :scanners, if: :scanners_changed?, inclusion: { in: SUPPORTED_SCANNERS }
  validates :vulnerabilities_allowed, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :severity_levels, inclusion: { in: ::Enums::Vulnerability.severity_levels.keys }
  validates :vulnerability_states, inclusion: { in: APPROVAL_VULNERABILITY_STATES.keys }
  validates :protected_branches, presence: true, if: -> { scan_finding? && !applies_to_all_protected_branches? }

  delegate :vulnerability_attributes, to: :scan_result_policy_read, allow_nil: true

  override :vulnerability_attribute_false_positive
  def vulnerability_attribute_false_positive
    vulnerability_attributes&.dig('false_positive')
  end

  override :vulnerability_attribute_fix_available
  def vulnerability_attribute_fix_available
    vulnerability_attributes&.dig('fix_available')
  end

  def applies_to_branch?(branch)
    return !applies_to_all_protected_branches? if protected_branches.empty?

    protected_branches.matching(branch).any?
  end

  def protected_branches
    return project.all_protected_branches if applies_to_all_protected_branches?

    super
  end

  def source_rule
    nil
  end

  def section
    nil
  end

  def apply_report_approver_rules_to(merge_request)
    Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification.temporary_ignore_tables_in_transaction(
      %w[approval_merge_request_rules users namespaces approval_merge_request_rules_users approval_merge_request_rules_groups],
      url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/417459') do
      ApplicationRecord.transaction do
        rule = merge_request_report_approver_rule(merge_request)
        rule.update!(report_approver_attributes)

        next rule unless Feature.enabled?(:scan_result_any_merge_request, merge_request.project)
        next rule unless rule.scan_result_policy_id

        Security::ScanResultPolicyViolation.upsert_all(
          [merge_request_id: merge_request.id,
           scan_result_policy_id: rule.scan_result_policy_id,
           project_id: merge_request.project_id],
          unique_by: %w[scan_result_policy_id merge_request_id])

        rule
      end
    end
  end

  def audit_add(model)
    push_audit_event("Added #{model.class.name} #{model.name} to approval group on #{self.name} rule")
  end

  def audit_creation
    push_audit_event("Added approval rule with number of required approvals of #{approvals_required}")
  end

  def audit_remove(model)
    push_audit_event("Removed #{model.class.name} #{model.name} from approval group on #{self.name} rule")
  end

  def vulnerability_states_for_branch(branch = project.default_branch)
    if applies_to_branch?(branch)
      self.vulnerability_states
    else
      self.vulnerability_states.select { |state| NEWLY_DETECTED == state }
    end
  end

  # No scanners specified in a vulnerability approval rule means all scanners will be used.
  # scan result policy approval rules require at least one scanner.
  # We also want to prevent nil values from being assigned.
  def scanners=(value)
    super(Array.wrap(value))
  end

  # For initialization of merge request approval rules
  def to_nested_attributes
    {
      name: name,
      approval_project_rule_id: id,
      user_ids: user_ids,
      group_ids: group_ids,
      approvals_required: approvals_required,
      rule_type: rule_type
    }
  end

  private

  # There are NULL values in the database and we want to convert them to empty arrays.
  def set_scanners_default_value
    # `scanners` might not be included in all `select` queries
    return unless has_attribute?(:scanners)

    self.scanners ||= read_attribute(:scanners)
  end

  def report_approver_attributes
    attributes
      .slice('approvals_required', 'name', 'orchestration_policy_idx', 'scanners', 'severity_levels', 'vulnerability_states', 'vulnerabilities_allowed', 'security_orchestration_policy_configuration_id', 'scan_result_policy_id')
      .merge(
        users: users,
        groups: groups,
        approval_project_rule: self,
        rule_type: :report_approver,
        report_type: report_type
      )
  end

  def merge_request_report_approver_rule(merge_request)
    if scan_finding? || license_scanning? || any_merge_request?
      merge_request
        .approval_rules
        .report_approver
        .joins(:approval_merge_request_rule_source)
        .where(approval_merge_request_rule_source: { approval_project_rule_id: self.id })
        .first_or_initialize
    else
      merge_request
        .approval_rules
        .report_approver
        .find_or_initialize_by(report_type: report_type)
    end
  end

  def validate_security_report_approver_name
    [
      [DEFAULT_NAME_FOR_COVERAGE, 'code_coverage']
    ].each do |report|
      name_type = { name: report[0], type: report[1] }

      validate_name_type(name_type)
    end
  end

  def validate_name_type(name_type)
    if name != name_type[:name] && report_type == name_type[:type]
      errors.add(:report_type, _("%{type} only supports %{name} name") % name_type)

    elsif name == name_type[:name] && report_type != name_type[:type]
      errors.add(:name, _("%{name} is reserved for %{type} report type") % name_type)
    end
  end

  def track_creation_event
    Gitlab::UsageDataCounters::HLLRedisCounter.track_event(APPROVAL_PROJECT_RULE_CREATION_EVENT, values: self.id)
  end
end
