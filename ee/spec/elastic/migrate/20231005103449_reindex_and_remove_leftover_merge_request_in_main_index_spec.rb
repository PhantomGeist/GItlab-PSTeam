# frozen_string_literal: true

require 'spec_helper'
require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20231005103449_reindex_and_remove_leftover_merge_request_in_main_index.rb')

RSpec.describe ReindexAndRemoveLeftoverMergeRequestInMainIndex, :elastic, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20231005103449 }
  let(:migration) { described_class.new(version) }
  let(:helper) { Gitlab::Elastic::Helper.new }
  let(:client) { ::Gitlab::Search::Client.new }
  let_it_be(:merge_requests) { create_list(:merge_request, 6) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    allow(migration).to receive(:helper).and_return(helper)
    allow(migration).to receive(:client).and_return(client)
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration.batched?).to be_truthy
      expect(migration).to be_retry_on_failure
      expect(migration.batch_size).to eq(1000)
      expect(migration.throttle_delay).to eq(3.minutes)
    end
  end

  describe '.completed?' do
    before do
      MergeRequest.all.each { |mr| populate_merge_requests_in_main_index!(mr) }
    end

    context 'when no merge_request documents are in the main index' do
      before do
        client.delete_by_query(index: helper.target_name, conflicts: 'proceed', refresh: true,
          body: { query: { bool: { filter: { term: { type: 'merge_request' } } } } }
        )
      end

      it 'returns true' do
        expect(migration).to be_completed
      end
    end

    context 'when merge_request documents exists in the main index' do
      it 'returns false' do
        expect(migration).not_to be_completed
      end
    end
  end

  describe '.migrate' do
    let(:batch_size) { 1 }

    before do
      allow(migration).to receive(:batch_size).and_return(batch_size)
      MergeRequest.all.each { |mr| populate_merge_requests_in_main_index!(mr) }
    end

    context 'if migration is completed' do
      before do
        client.delete_by_query(index: helper.target_name, conflicts: 'proceed', refresh: true,
          body: { query: { bool: { filter: { term: { type: 'merge_request' } } } } }
        )
      end

      it 'performs logging and does not call Elastic::ProcessBookkeepingService' do
        expect(migration).to receive(:log).with("Setting migration_state to #{{ documents_remaining: 0 }.to_json}").once
        expect(migration).to receive(:log).with('Checking if migration is finished', { total_remaining: 0 }).once
        expect(migration).to receive(:log).with('Migration Completed', { total_remaining: 0 }).once
        expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)
        migration.migrate
      end
    end

    context 'if migration is not completed' do
      it 'calls Elastic::ProcessBookkeepingService' do
        initial_documents_left_to_be_indexed_count = documents_left_to_be_indexed_count
        expect(initial_documents_left_to_be_indexed_count).to be > 0 # Ensure that the migration is not already finished
        expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(anything).once
        expect(migration).not_to be_completed
        migration.migrate
        to_be_indexed_count = initial_documents_left_to_be_indexed_count - batch_size
        expect(documents_left_to_be_indexed_count).to eq to_be_indexed_count
        expect(migration).not_to be_completed
        expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(anything).exactly(to_be_indexed_count).times
        10.times do
          break if migration.completed?

          migration.migrate
          sleep 0.01
        end
        expect(documents_left_to_be_indexed_count).to eq 0
        expect(migration).to be_completed
      end
    end
  end

  def populate_merge_requests_in_main_index!(mr)
    client.index(index: helper.target_name, routing: "project_#{mr.project_id}", id: "merge_request_#{mr.id}",
      refresh: true, body: {
        id: mr.id, iid: mr.iid, target_branch: mr.target_branch, source_branch: mr.source_branch, title: mr.title,
        description: mr.description, state: mr.state, merge_status: mr.merge_status, project_id: mr.project_id,
        source_project_id: mr.source_project_id, target_project_id: mr.target_project_id, author_id: mr.author_id,
        created_at: mr.created_at.strftime('%Y-%m-%dT%H:%M:%S.%3NZ'), visibility_level: mr.project.visibility_level,
        updated_at: mr.updated_at.strftime('%Y-%m-%dT%H:%M:%S.%3NZ'),
        join_field: { name: 'merge_request', parent: "project_#{mr.project_id}" }, type: 'merge_request',
        merge_requests_access_level: mr.project.merge_requests_access_level
      }
    )
  end

  def documents_left_to_be_indexed_count
    helper.refresh_index(index_name: helper.target_name)
    client.count(index: helper.target_name, body: { query: query })['count']
  end

  def query
    { bool: { filter: { term: { type: 'merge_request' } } } }
  end
end
