# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::RepositoryCheck::BatchWorker, feature_category: :source_code_management do
  include ::EE::GeoHelpers

  let(:shard_name) { 'default' }

  subject(:worker) { RepositoryCheck::BatchWorker.new }

  before do
    Gitlab::ShardHealthCache.update([shard_name])
  end

  context 'with Geo enabled' do
    let_it_be(:primary) { create(:geo_node, :primary) }
    let_it_be(:secondary) { create(:geo_node, :secondary) }

    context 'on a Geo primary site' do
      before do
        stub_current_geo_node(primary)
      end

      it 'loads project ids from main database' do
        projects = create_list(:project, 3, created_at: 1.week.ago, repository_storage: shard_name)

        expect(worker.perform(shard_name)).to match_array(projects.map(&:id))
      end
    end

    context 'Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does nothing' do
        create(:project, created_at: 1.week.ago)

        expect(subject.perform(shard_name)).to eq(nil)
      end
    end
  end
end
