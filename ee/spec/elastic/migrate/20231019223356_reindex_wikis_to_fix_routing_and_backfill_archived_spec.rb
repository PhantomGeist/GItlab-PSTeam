# frozen_string_literal: true

require 'spec_helper'
require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20231019223356_reindex_wikis_to_fix_routing_and_backfill_archived.rb')

RSpec.describe ReindexWikisToFixRoutingAndBackfillArchived, :elastic_clean, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20231019223356 }
  let(:migration) { described_class.new(version) }
  let(:helper) { Gitlab::Elastic::Helper.new }
  let(:client) { ::Gitlab::Search::Client.new }
  let(:index_name) { Elastic::Latest::WikiConfig.index_name }
  let_it_be(:project) { create(:project, :wiki_repo) }
  let_it_be(:project2) { create(:project, :wiki_repo) }
  let_it_be(:project3) { create(:project, :wiki_repo) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group2) { create(:group) }
  let_it_be(:group3) { create(:group) }
  let_it_be(:group_wiki) { create(:group_wiki, group: group) }
  let_it_be(:group_wiki2) { create(:group_wiki, group: group2) }
  let_it_be(:group_wiki3) { create(:group_wiki, group: group3) }
  let_it_be(:project_wiki) { create(:project_wiki, project: project) }
  let_it_be(:project_wiki2) { create(:project_wiki, project: project2) }
  let_it_be(:project_wiki3) { create(:project_wiki, project: project3) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_indexes_project?).with(anything).and_return true
    allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_indexes_namespace?).with(anything).and_return true
    allow(migration).to receive(:helper).and_return(helper)
    set_elasticsearch_migration_to :reindex_wikis_to_fix_routing, including: false
    allow(migration).to receive(:client).and_return(client)
    [project_wiki, project_wiki2, project_wiki3, group_wiki, group_wiki2, group_wiki3].each do |wiki|
      wiki.create_page('index_page', 'Bla bla term')
      wiki.create_page('index_page2', 'Bla bla term')
      wiki.index_wiki_blobs
    end
    ensure_elasticsearch_index! # ensure objects are indexed
  end

  describe 'migration_options' do
    before do
      set_old_schema_version_in_all_documents!
    end

    it 'has migration options set', :aggregate_failures do
      batch_size = [migration.get_number_of_shards(index_name: index_name), described_class::MAX_BATCH_SIZE].min
      expect(migration).to be_batched
      expect(migration.batch_size).to eq batch_size
      expect(migration.throttle_delay).to eq(5.minutes)
      expect(migration).to be_retry_on_failure
    end
  end

  describe '.migrate' do
    context 'if migration is completed' do
      it 'performs logging and does not call ElasticWikiIndexerWorker' do
        expect(migration).to receive(:log).with("Setting migration_state to #{{ documents_remaining: 0 }.to_json}").once
        expect(migration).to receive(:log).with('Checking if migration is finished', { total_remaining: 0 }).once
        expect(migration).to receive(:log).with('Migration Completed', { total_remaining: 0 }).once
        expect(ElasticWikiIndexerWorker).not_to receive(:perform_in)
        migration.migrate
      end
    end

    context 'if migration is not completed' do
      let(:batch_size) { migration.batch_size }

      before do
        set_old_schema_version_in_all_documents!
      end

      it 'performs logging and calls ElasticWikiIndexerWorker' do
        expect(migration).to receive(:log)
          .with("Setting migration_state to #{{ documents_remaining: 2 * total_rids }.to_json}").once
        expect(migration).to receive(:log).with("Setting migration_state to #{{ batch_size: batch_size }.to_json}").once
        expect(migration).to receive(:log).with('Checking if migration is finished',
          { total_remaining: 2 * total_rids }).once
        delay = a_value_between(0, migration.throttle_delay.seconds)
        expect(ElasticWikiIndexerWorker).to receive(:perform_in).exactly(batch_size).times.with(delay, anything,
          anything, force: true)

        migration.migrate
      end
    end
  end

  describe 'integration test' do
    let(:batch_size) { 2 }

    before do
      set_old_schema_version_in_all_documents!
      allow(migration).to receive(:batch_size).and_return(batch_size)
      # Remove elasticsearch for project2 and group2
      allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_indexes_project?).with(project2).and_return false
      allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_indexes_namespace?).with(group2).and_return false
      # Delete project3 and group3
      project3.delete
      group3.delete
    end

    it "migration will be completed and delete docs of the container that don't use elasticsearch or deleted" do
      initial_rids_to_reindex = total_rids
      expect(remaining_rids_to_reindex).to eq initial_rids_to_reindex
      expect(migration).not_to be_completed
      migration.migrate
      expect(migration).not_to be_completed
      expect(remaining_rids_to_reindex).to eq initial_rids_to_reindex - batch_size
      10.times do
        break if migration.completed?

        migration.migrate
        sleep 0.01
      end
      expect(migration).to be_completed
      # Less project3(deleted), group3(deleted), project2(not used elasticsearch), group2(not used elasticsearch)
      expect(total_rids).to eq initial_rids_to_reindex - 4
    end
  end

  describe '.completed?' do
    subject { migration.completed? }

    context 'when all the documents have the new schema_version(2310)' do
      # With the 4.4.0 GITLAB_ELASTICSEARCH_INDEXER_VERSION all the new wikis will have schema_version 2310
      it 'returns true' do
        is_expected.to be true
      end
    end

    context 'when some items are missing new schema_version' do
      before do
        set_old_schema_version_in_all_documents!
      end

      it 'returns false' do
        is_expected.to be false
      end
    end
  end

  def set_old_schema_version_in_all_documents!
    client.update_by_query(index: index_name, refresh: true, conflicts: 'proceed',
      body: { script: { lang: 'painless', source: 'ctx._source.schema_version = 2309' } }
    )
  end

  def total_rids
    helper.refresh_index(index_name: index_name)
    client.search(
      index: index_name, body: { size: 0, aggs: { rids: { terms: { field: 'rid' } } } }
    ).dig('aggregations', 'rids', 'buckets').size
  end

  def remaining_rids_to_reindex
    helper.refresh_index(index_name: index_name)
    client.search(index: index_name,
      body: { size: 0, query: { range: { schema_version: { lt: described_class::SCHEMA_VERSION } } },
              aggs: { rids: { terms: { field: 'rid' } } } }).dig('aggregations', 'rids', 'buckets').size
  end
end
