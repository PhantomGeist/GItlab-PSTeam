# frozen_string_literal: true

module Vulnerabilities
  class Finding < ApplicationRecord
    include ShaAttribute
    include ::Gitlab::Utils::StrongMemoize
    include Presentable
    include ::VulnerabilityFindingHelpers

    # https://gitlab.com/groups/gitlab-org/-/epics/3148
    # https://gitlab.com/gitlab-org/gitlab/-/issues/214563#note_370782508 is why the table names are not renamed
    self.table_name = "vulnerability_occurrences"

    FINDINGS_PER_PAGE = 20
    MAX_NUMBER_OF_IDENTIFIERS = 20
    REPORT_TYPES_WITH_LOCATION_IMAGE = %w[container_scanning cluster_image_scanning].freeze
    SECRET_DETECTION_DEFAULT_COMMIT_SHA = "0000000"

    paginates_per FINDINGS_PER_PAGE

    sha_attribute :project_fingerprint
    sha_attribute :location_fingerprint

    belongs_to :project, inverse_of: :vulnerability_findings
    belongs_to :scanner, class_name: 'Vulnerabilities::Scanner'
    belongs_to :primary_identifier, class_name: 'Vulnerabilities::Identifier', inverse_of: :primary_findings, foreign_key: 'primary_identifier_id'
    belongs_to :vulnerability, class_name: 'Vulnerability', inverse_of: :findings, foreign_key: 'vulnerability_id'
    has_many :state_transitions, through: :vulnerability
    has_many :issue_links, through: :vulnerability
    has_many :merge_request_links, through: :vulnerability

    has_many :finding_identifiers, class_name: 'Vulnerabilities::FindingIdentifier', inverse_of: :finding, foreign_key: 'occurrence_id'
    has_many :identifiers, through: :finding_identifiers, class_name: 'Vulnerabilities::Identifier'

    has_many :finding_links, class_name: 'Vulnerabilities::FindingLink', inverse_of: :finding, foreign_key: 'vulnerability_occurrence_id'

    has_many :finding_remediations, class_name: 'Vulnerabilities::FindingRemediation', inverse_of: :finding, foreign_key: 'vulnerability_occurrence_id'
    has_many :remediations, through: :finding_remediations

    has_many :finding_pipelines, class_name: 'Vulnerabilities::FindingPipeline', inverse_of: :finding, foreign_key: 'occurrence_id'

    has_many :signatures, class_name: 'Vulnerabilities::FindingSignature', inverse_of: :finding

    has_many :vulnerability_flags, class_name: 'Vulnerabilities::Flag', inverse_of: :finding, foreign_key: 'vulnerability_occurrence_id'

    has_many :feedbacks, class_name: 'Vulnerabilities::Feedback', inverse_of: :finding, primary_key: 'uuid', foreign_key: 'finding_uuid'

    has_one :finding_evidence, class_name: 'Vulnerabilities::Finding::Evidence', inverse_of: :finding, foreign_key: 'vulnerability_occurrence_id'

    has_many :security_findings,
      class_name: 'Security::Finding',
      primary_key: :uuid,
      foreign_key: :uuid,
      inverse_of: :vulnerability_finding

    attribute :config_options, :ind_jsonb

    attr_writer :sha
    attr_accessor :scan, :found_by_pipeline

    enum confidence: ::Enums::Vulnerability.confidence_levels, _prefix: :confidence
    enum report_type: ::Enums::Vulnerability.report_types
    enum severity: ::Enums::Vulnerability.severity_levels, _prefix: :severity
    enum detection_method: ::Enums::Vulnerability.detection_methods

    validates :scanner, presence: true
    validates :project, presence: true
    validates :uuid, presence: true

    validates :primary_identifier, presence: true
    validates :project_fingerprint, presence: true
    validates :location_fingerprint, presence: true
    # Uniqueness validation doesn't work with binary columns, so save this useless query. It is enforce by DB constraint anyway.
    # TODO: find out why it fails
    # validates :location_fingerprint, presence: true, uniqueness: { scope: [:primary_identifier_id, :scanner_id, :ref, :pipeline_id, :project_id] }
    validates :name, presence: true
    validates :report_type, presence: true
    validates :severity, presence: true
    validates :detection_method, presence: true

    validates :metadata_version, presence: true
    validates :raw_metadata, presence: true
    validates :details, json_schema: { filename: 'vulnerability_finding_details', draft: 7 }

    validates :description, length: { maximum: 15000 }
    validates :solution, length: { maximum: 7000 }
    validates :cve, length: { maximum: 48400 }

    delegate :name, :external_id, to: :scanner, prefix: true, allow_nil: true

    scope :report_type, -> (type) { where(report_type: report_types[type]) }
    scope :ordered, -> { order(severity: :desc, confidence: :desc, id: :asc) }

    scope :by_report_types, -> (values) { where(report_type: values) }
    scope :by_projects, -> (values) { where(project_id: values) }
    scope :by_scanners, -> (values) { where(scanner_id: values) }
    scope :by_severities, -> (values) { where(severity: values) }
    scope :by_confidences, -> (values) { where(confidence: values) }
    scope :by_location_fingerprints, -> (values) { where(location_fingerprint: values) }
    scope :by_project_fingerprints, -> (values) { where(project_fingerprint: values) }
    scope :by_uuid, -> (uuids) { where(uuid: uuids) }
    scope :excluding_uuids, -> (uuids) { where.not(uuid: uuids) }
    scope :eager_load_comparison_entities, -> { includes(:scanner, :primary_identifier) }
    scope :by_primary_identifiers, -> (identifier_ids) { where(primary_identifier: identifier_ids) }

    scope :all_preloaded, -> do
      preload(:scanner, :identifiers, :feedbacks, project: [:namespace, :project_feature])
    end

    scope :scoped_project, -> { where('vulnerability_occurrences.project_id = projects.id') }
    scope :eager_load_vulnerability_flags, -> { includes(:vulnerability_flags) }
    scope :by_location_image, -> (images) do
      where(report_type: REPORT_TYPES_WITH_LOCATION_IMAGE)
        .where("vulnerability_occurrences.location -> 'image' ?| array[:images]", images: images)
    end
    scope :by_location_cluster, -> (cluster_ids) do
      where(report_type: 'cluster_image_scanning')
        .where("vulnerability_occurrences.location -> 'kubernetes_resource' -> 'cluster_id' ?| array[:cluster_ids]", cluster_ids: cluster_ids)
    end
    scope :by_location_cluster_agent, -> (agent_ids) do
      where(report_type: 'cluster_image_scanning')
        .where("vulnerability_occurrences.location -> 'kubernetes_resource' -> 'agent_id' ?| array[:agent_ids]", agent_ids: agent_ids)
    end

    alias_method :declarative_policy_subject, :project
    alias_attribute :finding_details, :details

    def self.counted_by_severity
      group(:severity).count.transform_keys do |severity|
        severities[severity]
      end
    end

    # sha can be sourced from a joined pipeline or set from the report
    def sha
      # Some analysers (like Secret Detection) that produce security findings may perform scans across Git history and
      # attach specific commit information to the finding. When this is the case, we _must_ use the commit SHA specified
      # in the security report to compute the blob URL, otherwise the URL will link to the incorrect revision of the file.
      #
      # We also need to ensure we _don't_ use the commit SHA from the report if it's the default placeholder value,
      # which is defined in the `secrets` analyzer:
      # https://gitlab.com/gitlab-org/security-products/analyzers/secrets/-/blob/7e1e03209495a209308f3e9e96c5a4a0d32e1d55/secret.go#L13-13
      commit_sha = location.dig("commit", "sha")
      # rubocop:disable Style/IfUnlessModifier
      if !commit_sha || commit_sha == SECRET_DETECTION_DEFAULT_COMMIT_SHA
        # Two layers of fallbacks.
        commit_sha = @sha || pipeline_branch
      end
      # rubocop:enable Style/IfUnlessModifier

      commit_sha
    end

    def state
      if vulnerability.nil? || vulnerability.detected?
        'detected'
      elsif vulnerability.resolved?
        'resolved'
      elsif vulnerability.dismissed? # fail-safe check for cases when dismissal feedback was lost or was not created
        'dismissed'
      else
        'confirmed'
      end
    end

    def source_code?
      source_code.present?
    end

    def vulnerable_code(lines: vulnerable_lines)
      strong_memoize_with(:vulnerable_code, lines) do
        source_code.lines[lines]&.join
      end
    end

    def self.related_dismissal_feedback
      Feedback.where('vulnerability_occurrences.uuid = vulnerability_feedback.finding_uuid')
              .for_dismissal
    end
    private_class_method :related_dismissal_feedback

    def self.dismissed
      where('EXISTS (?)', related_dismissal_feedback.select(1))
    end

    def self.undismissed
      where('NOT EXISTS (?)', related_dismissal_feedback.select(1))
    end

    def feedback(feedback_type:)
      load_feedback.find { |f| f.feedback_type == feedback_type }
    end

    def load_feedback
      BatchLoader.for(uuid).batch do |uuids, loader|
        finding_feedbacks = Vulnerabilities::Feedback.all_preloaded.where(finding_uuid: uuids.uniq)

        uuids.each do |finding_uuid|
          loader.call(
            finding_uuid,
            finding_feedbacks.select { |f| finding_uuid == f.finding_uuid }
          )
        end
      end
    end

    def dismissal_feedback
      feedback(feedback_type: 'dismissal')
    end

    def issue_feedback
      related_issues = vulnerability&.related_issues
      related_issues.blank? ? feedback(feedback_type: 'issue') : Vulnerabilities::Feedback.find_by(issue: related_issues)
    end

    def merge_request_feedback
      feedback(feedback_type: 'merge_request')
    end

    def metadata
      strong_memoize(:metadata) do
        data = Gitlab::Json.parse(raw_metadata)

        data = {} unless data.is_a?(Hash)

        data
      rescue JSON::ParserError
        {}
      end
    end

    def description
      super.presence || metadata.dig('description')
    end

    def solution
      super.presence || metadata.dig('solution') || remediations&.first&.dig('summary')
    end

    def location
      super.presence || metadata.fetch('location', {})
    end

    def file
      location.dig('file')
    end

    def image
      location.dig('image')
    end

    def links
      return metadata.fetch('links', []) if finding_links.load.empty?

      finding_links.as_json(only: [:name, :url])
    end

    def remediations
      return metadata.dig('remediations') unless super.present?

      super.as_json(only: [:summary], methods: [:diff])
    end

    def build_evidence_request(data)
      return if data.nil?

      {
        headers: data.fetch('headers', []).map do |request_header|
          {
            name: request_header['name'],
            value: request_header['value']
          }
        end,
        method: data['method'],
        url: data['url'],
        body: data['body']
      }
    end

    def build_evidence_response(data)
      return if data.nil?

      {
        headers: data.fetch('headers', []).map do |header_data|
          {
            name: header_data['name'],
            value: header_data['value']
          }
        end,
        status_code: data['status_code'],
        reason_phrase: data['reason_phrase'],
        body: data['body']
      }
    end

    def build_evidence_supporting_messages(data)
      return [] if data.nil?

      data.map do |message|
        {
          name: message['name'],
          request: build_evidence_request(message['request']),
          response: build_evidence_response(message['response'])
        }
      end
    end

    def build_evidence_source(data)
      return if data.nil?

      {
        id: data['id'],
        name: data['name'],
        url: data['url']
      }
    end

    def evidence
      evidence_data = finding_evidence.present? ? finding_evidence.data : metadata.dig('evidence')

      return if evidence_data.nil?

      {
        summary: evidence_data&.dig('summary'),
        request: build_evidence_request(evidence_data&.dig('request')),
        response: build_evidence_response(evidence_data&.dig('response')),
        source: build_evidence_source(evidence_data&.dig('source')),
        supporting_messages: build_evidence_supporting_messages(evidence_data&.dig('supporting_messages'))
      }
    end

    def cve_value
      identifiers.find(&:cve?)&.name
    end

    def cwe_value
      identifiers.find(&:cwe?)&.name
    end

    def other_identifier_values
      identifiers.select(&:other?).map(&:name)
    end

    def assets
      metadata.fetch('assets', []).map do |asset_data|
        {
          name: asset_data['name'],
          type: asset_data['type'],
          url: asset_data['url']
        }
      end
    end

    alias_method :==, :eql?

    def eql?(other)
      return false unless other.is_a?(self.class)

      unless other.report_type == report_type && other.primary_identifier_fingerprint == primary_identifier_fingerprint
        return false
      end

      if project.licensed_feature_available?(:vulnerability_finding_signatures)
        matches_signatures(other.signatures, other.uuid)
      else
        other.location_fingerprint == location_fingerprint
      end
    end

    # Array.difference (-) method uses hash and eql? methods to do comparison
    def hash
      # This is causing N+1 queries whenever we are calling findings, ActiveRecord uses #hash method to make sure the
      # array with findings is uniq before preloading. This method is used only in Gitlab::Ci::Reports::Security::VulnerabilityReportsComparer
      # where we are normalizing security report findings into instances of Vulnerabilities::Finding, this is why we are using original implementation
      # when Finding is persisted and identifiers are not preloaded.
      return super if persisted? && !identifiers.loaded?

      report_type.hash ^ location_fingerprint.hash ^ primary_identifier_fingerprint.hash
    end

    def severity_value
      self.class.severities[self.severity]
    end

    def confidence_value
      self.class.confidences[self.confidence]
    end

    # We will eventually have only UUIDv5 values for the `uuid`
    # attribute of the finding records.
    def uuid_v5
      if Gitlab::UUID.v5?(uuid)
        uuid
      else
        ::Security::VulnerabilityUUID.generate(
          report_type: report_type,
          primary_identifier_fingerprint: primary_identifier.fingerprint,
          location_fingerprint: location_fingerprint,
          project_id: project_id
        )
      end
    end

    def self.pluck_uuids
      pluck(:uuid)
    end

    def self.pluck_vulnerability_ids
      pluck(:vulnerability_id)
    end

    def pipeline_branch
      last_finding_pipeline&.sha || project.default_branch
    end

    def false_positive?
      vulnerability_flags.any?(&:false_positive?)
    end

    def first_finding_pipeline
      finding_pipelines.first&.pipeline
    end

    def last_finding_pipeline
      finding_pipelines.last&.pipeline
    end

    protected

    def primary_identifier_fingerprint
      identifiers.first&.fingerprint
    end

    private

    def vulnerable_lines
      # -1 is a magic number here meaning an explicit value
      # for start_line or end_line was not provided.  If neither
      # were provided we return the entire file contents.
      return (0..-1) if (start_line < 0) && (end_line < 0)

      range_start = [start_line, 0].max
      range_end = [end_line, range_start].max

      (range_start..range_end)
    end

    def start_line
      location["start_line"].to_i - 1
    end

    def end_line
      location["end_line"].to_i - 1
    end

    def source_code
      return "" unless file.present?

      blob = project.repository.blob_at(pipeline_branch, file)
      blob.present? ? blob.data : ""
    end
    strong_memoize_attr :source_code
  end
end

Vulnerabilities::Finding.prepend_mod
