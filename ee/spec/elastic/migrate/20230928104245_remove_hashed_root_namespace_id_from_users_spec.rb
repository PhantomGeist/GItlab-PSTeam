# frozen_string_literal: true

require 'spec_helper'
require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20230928104245_remove_hashed_root_namespace_id_from_users.rb')

RSpec.describe RemoveHashedRootNamespaceIdFromUsers, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20230928104245 }
  let(:migration) { described_class.new(version) }
  let(:client) { ::Gitlab::Search::Client.new }
  let(:users) { create_list(:user, 6) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    users
    ensure_elasticsearch_index!
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(1.minute)
    end
  end

  describe '#completed?' do
    context 'when hashed_root_namespace_id is present in the mapping' do
      before do
        add_hashed_root_namespace_id_in_mapping!
      end

      context 'when some documents have the value for hashed_root_namespace_id set' do
        before do
          add_hashed_root_namespace_id_value_to_documents!(3)
        end

        it 'returns false' do
          expect(migration.completed?).to eq false
        end
      end

      context 'when no documents have the value for hashed_root_namespace_id set' do
        it 'returns true' do
          expect(migration.completed?).to eq true
        end
      end
    end

    context 'when hashed_root_namespace_id is not present in the mapping' do
      it 'returns true' do
        expect(migration.completed?).to eq true
      end
    end
  end

  describe '#migrate' do
    let(:original_target_doc_count) { 5 }
    let(:batch_size) { 2 }

    before do
      add_hashed_root_namespace_id_in_mapping!
      add_hashed_root_namespace_id_value_to_documents!(original_target_doc_count)
      allow(migration).to receive(:batch_size).and_return(batch_size)
    end

    it 'completes the migration in batches' do
      expect(documents_count_with_hashed_root_namespace_id).to eq original_target_doc_count
      expect(migration.completed?).to eq false
      migration.migrate
      expect(migration.completed?).to eq false
      expect(documents_count_with_hashed_root_namespace_id).to eq original_target_doc_count - batch_size
      10.times do
        break if migration.completed?

        migration.migrate
        sleep 0.01
      end
      expect(migration.completed?).to eq true
      expect(documents_count_with_hashed_root_namespace_id).to eq 0
    end
  end

  def add_hashed_root_namespace_id_in_mapping!
    client.indices.put_mapping(index: User.__elasticsearch__.index_name,
      body: { properties: { hashed_root_namespace_id: { type: 'integer' } } }
    )
  end

  def add_hashed_root_namespace_id_value_to_documents!(count)
    client.update_by_query(index: User.__elasticsearch__.index_name, refresh: true, body: {
      script: { source: "ctx._source.hashed_root_namespace_id=1" }, max_docs: count
    })
  end

  def documents_count_with_hashed_root_namespace_id
    client.count(index: User.__elasticsearch__.index_name,
      body: { query: { bool: { must: { exists: { field: 'hashed_root_namespace_id' } } } } }
    )['count']
  end
end
