# frozen_string_literal: true

require 'spec_helper'
require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20231004124852_reindex_and_remove_leftover_notes_from_main_index.rb')

RSpec.describe ReindexAndRemoveLeftoverNotesFromMainIndex, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20231004124852 }
  let(:migration) { described_class.new(version) }
  let(:helper) { Gitlab::Elastic::Helper.new }
  let(:client) { ::Gitlab::Search::Client.new }
  let_it_be_with_reload(:notes) { create_list(:note, 6) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    allow(migration).to receive(:helper).and_return(helper)
    allow(migration).to receive(:client).and_return(client)
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration.batched?).to be_truthy
      expect(migration).to be_retry_on_failure
      expect(migration.batch_size).to eq(2000)
      expect(migration.throttle_delay).to eq(3.minutes)
    end
  end

  describe '.completed?' do
    before do
      Note.all.each { |n| populate_notes_in_main_index!(n) }
    end

    context 'when no notes documents are in the main index' do
      before do
        client.delete_by_query(index: helper.target_name, conflicts: 'proceed', refresh: true,
          body: { query: { bool: { filter: { term: { type: 'note' } } } } }
        )
      end

      it 'returns true' do
        expect(migration).to be_completed
      end
    end

    context 'when notes documents exists in the main index' do
      it 'returns false' do
        expect(migration).not_to be_completed
      end
    end
  end

  describe '.migrate' do
    let(:batch_size) { 1 }

    before do
      allow(migration).to receive(:batch_size).and_return(batch_size)
      Note.all.each { |n| populate_notes_in_main_index!(n) }
    end

    context 'if migration is completed' do
      before do
        client.delete_by_query(index: helper.target_name, conflicts: 'proceed', refresh: true,
          body: { query: { bool: { filter: { term: { type: 'note' } } } } }
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

  def populate_notes_in_main_index!(note)
    client.index(index: helper.target_name, routing: "project_#{note.project_id}", id: "note_#{note.id}", refresh: true,
      body: {
        id: note.id, note: note.note, noteable_type: note.noteable_type, noteable_id: note.noteable_id,
        created_at: note.created_at.strftime('%Y-%m-%dT%H:%M:%S.%3NZ'),
        updated_at: note.updated_at.strftime('%Y-%m-%dT%H:%M:%S.%3NZ'),
        issue: { assignee_id: [], author_id: note.author_id, confidential: note.noteable.try(:confidential?).presence },
        join_field: { name: 'note', parent: "project_#{note.project_id}" }, project_id: note.project_id,
        repository_access_level: note.project.repository_access_level, visibility_level: note.project.visibility_level,
        issues_access_level: note.project.issues_access_level, type: 'note', confidential: note.confidential?
      }
    )
  end

  def indexed_documents_count
    helper.refresh_index(index_name: Elastic::Latest::NoteConfig.index_name)
    client.count(index: Elastic::Latest::NoteConfig.index_name, body: { query: query })['count']
  end

  def documents_left_to_be_indexed_count
    helper.refresh_index(index_name: helper.target_name)
    client.count(index: helper.target_name, body: { query: query })['count']
  end

  def query
    { bool: { filter: { term: { type: 'note' } } } }
  end
end
