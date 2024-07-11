# frozen_string_literal: true

class GeoNodeStatus < ApplicationRecord
  include IgnorableColumns
  include ShaAttribute

  ignore_columns(
    %i[
      wikis_checksum_failed_count
      wikis_checksum_mismatch_count
      wikis_checksummed_count
      wikis_failed_count
      wikis_retrying_verification_count
      wikis_synced_count
      wikis_verification_failed_count
      wikis_verified_count
      design_repositories_count
      design_repositories_synced_count
      design_repositories_failed_count
      design_repositories_registry_count
    ],
    remove_with: '16.5',
    remove_after: '2023-09-22'
  )

  ignore_columns(
    %i[
      repositories_synced_count
      repositories_failed_count
      repositories_verified_count
      repositories_verification_failed_count
      repositories_checksummed_count
      repositories_checksum_failed_count
      repositories_checksum_mismatch_count
      repositories_retrying_verification_count
    ],
    remove_with: '16.6',
    remove_after: '2023-10-22'
  )

  ignore_columns(
    %i[
      container_repositories_count
      container_repositories_failed_count
      container_repositories_registry_count
      container_repositories_synced_count
      job_artifacts_count
      job_artifacts_failed_count
      job_artifacts_synced_count
      job_artifacts_synced_missing_on_primary_count
      lfs_objects_count
      lfs_objects_failed_count
      lfs_objects_synced_count
      lfs_objects_synced_missing_on_primary_count
    ],
    remove_with: '16.7',
    remove_after: '2023-11-22'
  )

  belongs_to :geo_node

  delegate :selective_sync_type, to: :geo_node

  after_initialize :initialize_feature_flags
  before_save :coerce_status_field_values, if: :status_changed?

  attr_accessor :storage_shards

  # Prometheus metrics, no need to store them in the database
  attr_accessor :event_log_max_id, :repositories_checked_count, :repositories_checked_failed_count

  sha_attribute :storage_configuration_digest

  alias_attribute :repositories_count, :projects_count

  attribute_method_suffix '_timestamp', '_timestamp='

  alias_attribute :last_successful_status_check_timestamp, :last_successful_status_check_at_timestamp
  alias_attribute :last_event_timestamp, :last_event_date_timestamp
  alias_attribute :cursor_last_event_timestamp, :cursor_last_event_date_timestamp

  scope :for_active_secondaries, -> { joins(:geo_node).merge(GeoNode.secondary_nodes.where(enabled: true)) }

  def self.status_fields_for(replicable_class)
    {
      "#{replicable_class.replicable_name_plural}_count".to_sym => "Number of #{replicable_class.replicable_title_plural} on the primary",
      "#{replicable_class.replicable_name_plural}_checksum_total_count".to_sym => "Number of #{replicable_class.replicable_title_plural} available to checksum on primary",
      "#{replicable_class.replicable_name_plural}_checksummed_count".to_sym => "Number of #{replicable_class.replicable_title_plural} checksummed on the primary",
      "#{replicable_class.replicable_name_plural}_checksum_failed_count".to_sym => "Number of #{replicable_class.replicable_title_plural} failed to checksum on primary",
      "#{replicable_class.replicable_name_plural}_synced_count".to_sym => "Number of #{replicable_class.replicable_title_plural} in the registry",
      "#{replicable_class.replicable_name_plural}_failed_count".to_sym => "Number of #{replicable_class.replicable_title_plural} failed on secondary",
      "#{replicable_class.replicable_name_plural}_registry_count".to_sym => "Number of #{replicable_class.replicable_title_plural} synced to sync on secondary",
      "#{replicable_class.replicable_name_plural}_verification_total_count".to_sym => "Number of #{replicable_class.replicable_title_plural} available to verify on secondary",
      "#{replicable_class.replicable_name_plural}_verified_count".to_sym => "Number of #{replicable_class.replicable_title_plural} verified on the secondary",
      "#{replicable_class.replicable_name_plural}_verification_failed_count".to_sym => "Number of #{replicable_class.replicable_title_plural} failed to verify on secondary"
    }
  end

  # Why are disabled classes included? See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/38959#note_402656534
  def self.replicator_class_status_fields
    Gitlab::Geo::REPLICATOR_CLASSES.map do |replicable_class|
      status_fields_for(replicable_class).keys
    end.flatten.map(&:to_s)
  end

  def self.usage_data_fields
    Geo::SecondaryUsageData::PAYLOAD_COUNT_FIELDS
  end

  RESOURCE_STATUS_FIELDS = (%w[
    projects_count
    container_repositories_replication_enabled
  ] + replicator_class_status_fields + usage_data_fields).freeze

  # Why are disabled classes included? See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/38959#note_402656534
  def self.replicator_class_prometheus_metrics
    Gitlab::Geo::REPLICATOR_CLASSES.map do |replicable_class|
      status_fields_for(replicable_class)
    end.reduce({}, :merge)
  end

  # Be sure to keep this consistent with Prometheus naming conventions
  PROMETHEUS_METRICS = {
    db_replication_lag_seconds: 'Database replication lag (seconds)',
    repositories_count: 'Total number of repositories available on primary',
    replication_slots_count: 'Total number of replication slots on the primary',
    replication_slots_used_count: 'Number of replication slots in use on the primary',
    replication_slots_max_retained_wal_bytes: 'Maximum number of bytes retained in the WAL on the primary',
    last_event_id: 'Database ID of the latest event log entry on the primary',
    last_event_timestamp: 'Time of the latest event log entry on the primary',
    cursor_last_event_id: 'Last database ID of the event log processed by the secondary',
    cursor_last_event_timestamp: 'Time of the event log processed by the secondary',
    last_successful_status_check_timestamp: 'Time when Geo node status was updated internally',
    status_message: 'Summary of health status',
    event_log_max_id: 'Highest ID present in the Geo event log',
    repositories_checked_count: 'Number of repositories checked',
    repositories_checked_failed_count: 'Number of failed repositories checked',
    container_repositories_replication_enabled: 'Boolean denoting if replication is enabled for Container Repositories'
  }.merge(replicator_class_prometheus_metrics).freeze

  EXPIRATION_IN_MINUTES = 10
  HEALTHY_STATUS = 'Healthy'
  UNHEALTHY_STATUS = 'Unhealthy'

  def self.alternative_status_store_accessor(attr_names)
    attr_names.each do |attr_name|
      define_method(attr_name) do
        val = status[attr_name]

        # Backwards-compatible line for when the status was written by an
        # earlier release without the `status` field
        val ||= read_attribute(attr_name)

        convert_status_value(attr_name, val)
      end

      define_method("#{attr_name}=") do |val|
        val = convert_status_value(attr_name, val)

        status[attr_name] = val
      end
    end
  end

  alternative_status_store_accessor RESOURCE_STATUS_FIELDS

  def self.current_node_status
    current_node = Gitlab::Geo.current_node
    return unless current_node

    status = current_node.find_or_build_status
    status.load_data_from_current_node
    status.save if Gitlab::Geo.primary?

    status
  end

  def self.fast_current_node_status
    attrs = Rails.cache.read(cache_key)

    if attrs
      new(attrs)
    else
      spawn_worker
      nil
    end
  end

  def self.spawn_worker
    ::Geo::MetricsUpdateWorker.perform_async # rubocop:disable CodeReuse/Worker
  end

  def self.cache_key
    "geo-node:#{Gitlab::Geo.current_node.id}:status"
  end

  def self.from_json(json_data)
    json_data.slice!(*allowed_params)

    GeoNodeStatus.new(HashWithIndifferentAccess.new(json_data))
  end

  EXCLUDED_PARAMS = %w[id created_at].freeze
  EXTRA_PARAMS = %w[
    last_event_timestamp
    cursor_last_event_timestamp
    storage_shards
  ].freeze

  def self.allowed_params
    self.column_names - EXCLUDED_PARAMS + EXTRA_PARAMS
  end

  # Helps make alternative_status_store_accessor act more like regular Rails
  # attributes. Request params values are always strings, but when saved as
  # attributes of a model, they are converted to the appropriate types. We could
  # manually map a specified type to each attribute, but for now, the type can
  # be easily inferred by the attribute name.
  #
  # If you add a new status attribute that does not look like existing
  # attributes, then you'll get an error until you handle it in the cases below.
  #
  # @param [String] attr_name the status key
  # @param [String, Integer, Boolean] val being assigned or retrieved
  # @return [String, Integer, Boolean] converted value based on attr_name
  def convert_status_value(attr_name, val)
    return if val.nil?

    case attr_name
    when /_count(?:_weekly)?\z/ then val.to_i
    when /_enabled\z/ then val.to_s == 'true'
    else raise "Unhandled status attribute name format \"#{attr_name}\""
    end
  end

  # Leverages attribute reader methods written by
  # alternative_status_store_accessor to convert string values to integers and
  # booleans if necessary.
  def coerce_status_field_values
    status_attrs = status.slice(*RESOURCE_STATUS_FIELDS)
    self.assign_attributes(status_attrs)
  end

  def initialize_feature_flags
    if Gitlab::Geo.secondary?
      self.container_repositories_replication_enabled = Geo::ContainerRepositoryRegistry.replication_enabled?
    end
  end

  def update_cache!
    Rails.cache.write(self.class.cache_key, attributes)
  end

  def load_data_from_current_node
    self.event_log_max_id = Geo::EventLog.maximum(:id)

    latest_event = Geo::EventLog.latest_event
    self.last_event_id = latest_event&.id
    self.last_event_date = latest_event&.created_at
    self.last_successful_status_check_at = Time.current

    self.storage_shards = StorageShard.all
    self.storage_configuration_digest = StorageShard.build_digest

    self.version = Gitlab::VERSION
    self.revision = Gitlab.revision

    load_status_message
    load_primary_data
    load_secondary_data
    load_verification_data
  end

  def current_cursor_last_event_id
    return unless Gitlab::Geo.secondary?

    min_gap_id = ::Gitlab::Geo::EventGapTracking.min_gap_id
    last_processed_id = Geo::EventLogState.last_processed&.event_id

    [min_gap_id, last_processed_id].compact.min
  end

  def healthy?
    !outdated? && status_message_healthy?
  end

  def health
    status_message
  end

  def health_status
    healthy? ? HEALTHY_STATUS : UNHEALTHY_STATUS
  end

  def outdated?
    return false unless updated_at

    updated_at < EXPIRATION_IN_MINUTES.minutes.ago
  end

  def status_message_healthy?
    status_message.blank? || status_message == HEALTHY_STATUS
  end

  def attribute_timestamp(attr)
    self[attr].to_i
  end

  def attribute_timestamp=(attr, value)
    self[attr] = Time.zone.at(value)
  end

  def self.percentage_methods
    @percentage_methods || []
  end

  def self.attr_in_percentage(attr_name, count, total)
    method_name = "#{attr_name}_in_percentage"
    @percentage_methods ||= []
    @percentage_methods << method_name

    define_method(method_name) do
      return 0 if self[total].to_i == 0

      (self[count].to_f / self[total].to_f) * 100.0
    end
  end

  def self.add_attr_in_percentage_for_replicable_classes
    Gitlab::Geo::REPLICATOR_CLASSES.each do |replicator|
      replicable = replicator.replicable_name_plural
      attr_in_percentage "#{replicable}_synced",       "#{replicable}_synced_count",       "#{replicable}_registry_count"
      attr_in_percentage "#{replicable}_verified",     "#{replicable}_verified_count",     "#{replicable}_registry_count"
    end
  end

  attr_in_percentage :repositories_checked,          :repositories_checked_count,          :repositories_count
  attr_in_percentage :replication_slots_used,        :replication_slots_used_count,        :replication_slots_count

  add_attr_in_percentage_for_replicable_classes

  def synced_in_percentage_for(replicator_class)
    public_send("#{replicator_class.replicable_name_plural}_synced_in_percentage") # rubocop:disable GitlabSecurity/PublicSend
  end

  def verified_in_percentage_for(replicator_class)
    public_send("#{replicator_class.replicable_name_plural}_verified_in_percentage") # rubocop:disable GitlabSecurity/PublicSend
  end

  def count_for(replicator_class)
    public_send("#{replicator_class.replicable_name_plural}_count") # rubocop:disable GitlabSecurity/PublicSend
  end

  def storage_shards_match?
    return true if geo_node.primary?
    return false unless storage_configuration_digest && primary_storage_digest

    storage_configuration_digest == primary_storage_digest
  end

  def [](key)
    public_send(key) # rubocop:disable GitlabSecurity/PublicSend
  end

  private

  def load_status_message
    self.status_message =
      begin
        HealthCheck::Utils.process_checks(['geo'])
      rescue NotImplementedError => e
        e.to_s
      end
  end

  def load_primary_data
    return unless Gitlab::Geo.primary?

    self.projects_count = geo_node.projects.count
    self.replication_slots_count = geo_node.replication_slots_count
    self.replication_slots_used_count = geo_node.replication_slots_used_count
    self.replication_slots_max_retained_wal_bytes = geo_node.replication_slots_max_retained_wal_bytes
    self.repositories_checked_count = Project.where.not(last_repository_check_at: nil).count
    self.repositories_checked_failed_count = Project.where(last_repository_check_failed: true).count

    Gitlab::Geo::REPLICATOR_CLASSES.each do |replicator|
      public_send("#{replicator.replicable_name_plural}_count=", replicator.primary_total_count) # rubocop:disable GitlabSecurity/PublicSend
    end
  end

  def load_secondary_data
    return unless Gitlab::Geo.secondary?

    self.db_replication_lag_seconds = Gitlab::Geo::HealthCheck.new.db_replication_lag_seconds
    self.cursor_last_event_id = current_cursor_last_event_id
    self.cursor_last_event_date = Geo::EventLog.find_by(id: self.cursor_last_event_id)&.created_at
    self.projects_count = Geo::ProjectRepositoryReplicator.registry_count

    load_ssf_replicable_data
    load_secondary_usage_data
  end

  def load_ssf_replicable_data
    Gitlab::Geo.enabled_replicator_classes.each do |replicator|
      public_send("#{replicator.replicable_name_plural}_count=", replicator.registry_count) # rubocop:disable GitlabSecurity/PublicSend
      public_send("#{replicator.replicable_name_plural}_registry_count=", replicator.registry_count) # rubocop:disable GitlabSecurity/PublicSend
      public_send("#{replicator.replicable_name_plural}_synced_count=", replicator.synced_count) # rubocop:disable GitlabSecurity/PublicSend
      public_send("#{replicator.replicable_name_plural}_failed_count=", replicator.failed_count) # rubocop:disable GitlabSecurity/PublicSend
    end
  end

  def load_secondary_usage_data
    usage_data = Geo::SecondaryUsageData.last
    return unless usage_data

    self.class.usage_data_fields.each do |field|
      status[field] = usage_data.payload[field]
    end
  end

  def load_verification_data
    if Gitlab::Geo.primary?
      load_primary_verification_data
    elsif Gitlab::Geo.secondary?
      load_secondary_verification_data
    end
  end

  def load_primary_verification_data
    Gitlab::Geo::REPLICATOR_CLASSES.each do |replicator|
      next unless replicator.verification_feature_flag_enabled?

      public_send("#{replicator.replicable_name_plural}_checksummed_count=", replicator.checksummed_count) # rubocop:disable GitlabSecurity/PublicSend
      public_send("#{replicator.replicable_name_plural}_checksum_failed_count=", replicator.checksum_failed_count) # rubocop:disable GitlabSecurity/PublicSend
      public_send("#{replicator.replicable_name_plural}_checksum_total_count=", replicator.checksum_total_count) # rubocop:disable GitlabSecurity/PublicSend
    end
  end

  def load_secondary_verification_data
    ::Gitlab::Geo.verification_enabled_replicator_classes.each do |replicator|
      public_send("#{replicator.replicable_name_plural}_verified_count=", replicator.verified_count) # rubocop:disable GitlabSecurity/PublicSend
      public_send("#{replicator.replicable_name_plural}_verification_failed_count=", replicator.verification_failed_count) # rubocop:disable GitlabSecurity/PublicSend
      public_send("#{replicator.replicable_name_plural}_verification_total_count=", replicator.verification_total_count) # rubocop:disable GitlabSecurity/PublicSend
    end
  end

  def primary_storage_digest
    @primary_storage_digest ||= Gitlab::Geo.primary_node.find_or_build_status.storage_configuration_digest
  end
end
