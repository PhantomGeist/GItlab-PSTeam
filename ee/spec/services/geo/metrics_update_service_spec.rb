# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::MetricsUpdateService, :geo, :prometheus, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node) }
  let_it_be(:another_secondary) { create(:geo_node) }

  subject { described_class.new }

  let(:event_date) { Time.current.utc }

  let(:data) do
    {
      status_message: nil,
      db_replication_lag_seconds: 0,
      projects_count: 10,
      last_event_id: 2,
      last_event_date: event_date,
      cursor_last_event_id: 1,
      cursor_last_event_date: event_date,
      event_log_max_id: 555
    }
  end

  let(:primary_data) do
    {
      status_message: nil,
      projects_count: 10,
      last_event_id: 2,
      last_event_date: event_date,
      event_log_max_id: 555
    }
  end

  before do
    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check

    allow(Gitlab::Metrics).to receive(:prometheus_metrics_enabled?).and_return(true)
  end

  describe '#execute' do
    before do
      allow_any_instance_of(Geo::NodeStatusRequestService).to receive(:execute).and_return(true)
    end

    context 'when current node is nil' do
      before do
        stub_current_geo_node(nil)
      end

      it 'skips posting the status' do
        expect_any_instance_of(Geo::NodeStatusRequestService).not_to receive(:execute)

        subject.execute
      end
    end

    context 'when node is the primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'updates the cache' do
        status = GeoNodeStatus.from_json(primary_data.as_json)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(status)

        expect(status).to receive(:update_cache!)

        subject.execute
      end

      it 'updates metrics for all sites' do
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(GeoNodeStatus.from_json(primary_data.as_json))

        secondary.update!(status: GeoNodeStatus.from_json(data.as_json))
        another_secondary.update!(status: GeoNodeStatus.from_json(data.as_json))

        subject.execute

        expect(metric_value(:geo_repositories, geo_site: secondary)).to eq(10)
        expect(metric_value(:geo_repositories, geo_site: another_secondary)).to eq(10)
        expect(metric_value(:geo_repositories, geo_site: primary)).to eq(10)
      end

      it 'updates the GeoNodeStatus entry' do
        expect { subject.execute }.to change { GeoNodeStatus.count }.by(1)
      end
    end

    context 'when node is a secondary' do
      before do
        stub_current_geo_node(secondary)
        @status = GeoNodeStatus.new(data.as_json)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(@status)
      end

      it 'updates the cache' do
        expect(@status).to receive(:update_cache!)

        subject.execute
      end

      it 'adds gauges for various metrics' do
        subject.execute

        expect(metric_value(:geo_db_replication_lag_seconds)).to eq(0)
        expect(metric_value(:geo_last_event_id)).to eq(2)
        expect(metric_value(:geo_last_event_timestamp)).to eq(event_date.to_i)
        expect(metric_value(:geo_cursor_last_event_id)).to eq(1)
        expect(metric_value(:geo_cursor_last_event_timestamp)).to eq(event_date.to_i)
        expect(metric_value(:geo_last_successful_status_check_timestamp)).to be_truthy
        expect(metric_value(:geo_event_log_max_id)).to eq(555)
      end

      it 'increments a counter when metrics fail to retrieve' do
        allow_next_instance_of(Geo::NodeStatusRequestService) do |instance|
          allow(instance).to receive(:execute).and_return(false)
        end

        # Run once to get the gauge set
        subject.execute

        expect { subject.execute }.to change { metric_value(:geo_status_failed_total) }.by(1)
      end

      it 'does not create GeoNodeStatus entries' do
        expect { subject.execute }.to change { GeoNodeStatus.count }.by(0)
      end
    end

    def metric_value(metric_name, geo_site: secondary)
      Gitlab::Metrics.registry.get(metric_name)&.get({ name: geo_site.name, url: geo_site.name })
    end
  end
end
