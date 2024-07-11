# frozen_string_literal: true

require 'spec_helper'
require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20231016162120_reindex_epics_to_fix_label_ids.rb')

RSpec.describe ReindexEpicsToFixLabelIds, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20231016162120 }

  include_examples 'migration reindex based on schema_version' do
    let(:objects) { create_list(:epic, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 9000 }
  end
end
