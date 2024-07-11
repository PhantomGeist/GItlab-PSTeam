# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::NodeUpdateService, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:primary, reload: true) { create(:geo_node, :primary) }
  let_it_be(:geo_node) { create(:geo_node) }

  before do
    stub_current_geo_node(primary)
  end

  describe '#execute' do
    it 'updates the node' do
      params = { url: 'http://example.com' }
      service = described_class.new(geo_node, params)

      service.execute

      geo_node.reload
      expect(geo_node.url.chomp('/')).to eq(params[:url])
    end

    it 'returns true when update succeeds' do
      service = described_class.new(geo_node, { url: 'http://example.com' })

      expect(service.execute).to eq true
    end

    it 'returns false when update fails' do
      allow(geo_node).to receive(:update).and_return(false)

      service = described_class.new(geo_node, { url: 'http://example.com' })

      expect(service.execute).to eq false
    end
  end
end
