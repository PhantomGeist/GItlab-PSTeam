# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Node, feature_category: :global_search do
  let_it_be(:indexed_namespace1) { create(:namespace) }
  let_it_be(:indexed_namespace2) { create(:namespace) }
  let_it_be(:unindexed_namespace) { create(:namespace) }
  let(:node) { described_class.create!(index_base_url: 'http://example.com:1234/', search_base_url: 'http://example.com:4567/') }

  before do
    create(:zoekt_indexed_namespace, node: node, namespace: indexed_namespace1)
    create(:zoekt_indexed_namespace, node: node, namespace: indexed_namespace2)
  end

  it 'has many indexed_namespaces' do
    expect(node.indexed_namespaces.count).to eq(2)
    expect(node.indexed_namespaces.map(&:namespace)).to contain_exactly(indexed_namespace1, indexed_namespace2)
  end

  describe '.for_namespace' do
    it 'returns associated node' do
      expect(described_class.for_namespace(root_namespace_id: indexed_namespace1.id)).to eq(node)
    end

    it 'returns nil when no node is associated' do
      expect(described_class.for_namespace(root_namespace_id: unindexed_namespace.id)).to be_nil
    end
  end

  describe '.find_or_initialize_by_task_request', :freeze_time do
    let(:params) do
      {
        'uuid' => '3869fe21-36d1-4612-9676-0b783ef2dcd7',
        'node.name' => 'm1.local',
        'node.url' => 'http://localhost:6090',
        'disk.all' => 994662584320,
        'disk.used' => 532673712128,
        'disk.free' => 461988872192
      }
    end

    subject(:tasked_node) { described_class.find_or_initialize_by_task_request(params) }

    context 'when node does not exist for given UUID' do
      it 'returns a new record with correct attributes' do
        expect(tasked_node).not_to be_persisted
        expect(tasked_node.index_base_url).to eq(params['node.url'])
        expect(tasked_node.search_base_url).to eq(params['node.url'])
        expect(tasked_node.uuid).to eq(params['uuid'])
        expect(tasked_node.last_seen_at).to eq(Time.zone.now)
        expect(tasked_node.used_bytes).to eq(params['disk.used'])
        expect(tasked_node.total_bytes).to eq(params['disk.all'])
        expect(tasked_node.metadata['name']).to eq(params['node.name'])
      end
    end

    context 'when node already exists for given UUID' do
      it 'returns existing node and updates correct attributes' do
        node.update!(uuid: params['uuid'])

        expect(tasked_node).to be_persisted
        expect(tasked_node.id).to eq(node.id)
        expect(tasked_node.index_base_url).to eq(params['node.url'])
        expect(tasked_node.search_base_url).to eq(params['node.url'])
        expect(tasked_node.uuid).to eq(params['uuid'])
        expect(tasked_node.last_seen_at).to eq(Time.zone.now)
        expect(tasked_node.used_bytes).to eq(params['disk.used'])
        expect(tasked_node.total_bytes).to eq(params['disk.all'])
        expect(tasked_node.metadata['name']).to eq(params['node.name'])
      end
    end
  end
end
