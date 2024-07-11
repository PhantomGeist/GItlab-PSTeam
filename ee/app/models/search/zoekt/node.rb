# frozen_string_literal: true

module Search
  module Zoekt
    class Node < ApplicationRecord
      self.table_name = 'zoekt_shards'

      has_many :indexed_namespaces,
        foreign_key: :zoekt_shard_id, inverse_of: :node, class_name: '::Zoekt::IndexedNamespace'

      validates :index_base_url, presence: true, uniqueness: true
      validates :search_base_url, presence: true, uniqueness: true
      validates :uuid, presence: true, uniqueness: true
      validates :last_seen_at, presence: true
      validates :used_bytes, presence: true
      validates :total_bytes, presence: true
      validates :metadata, json_schema: { filename: 'zoekt_node_metadata' }

      attribute :metadata, :ind_jsonb # for indifferent access

      def self.for_namespace(root_namespace_id:)
        find_by(
          id: ::Zoekt::IndexedNamespace.where(namespace_id: root_namespace_id).select(:zoekt_shard_id)
        )
      end

      def self.find_or_initialize_by_task_request(params)
        params = params.with_indifferent_access

        find_or_initialize_by(uuid: params.fetch(:uuid)).tap do |s|
          # Note: if zoekt node makes task_request with a different `node.url`,
          # we will respect that and make change here.
          s.index_base_url = params.fetch("node.url")
          s.search_base_url = params.fetch("node.url")

          s.last_seen_at = Time.zone.now
          s.used_bytes = params.fetch("disk.used")
          s.total_bytes = params.fetch("disk.all")
          s.metadata['name'] = params.fetch("node.name")
        end
      end
    end
  end
end
