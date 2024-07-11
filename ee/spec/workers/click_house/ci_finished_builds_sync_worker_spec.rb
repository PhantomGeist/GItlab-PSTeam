# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::CiFinishedBuildsSyncWorker, :click_house, :freeze_time, feature_category: :runner_fleet do
  let(:worker) { described_class.new }

  let_it_be(:build1) { create(:ci_build, :success) }
  let_it_be(:build2) { create(:ci_build, :pending) }

  subject(:perform) { worker.perform }

  before do
    create_sync_events build1
  end

  include_examples 'an idempotent worker' do
    it 'calls CiFinishedBuildsSyncService and returns its response payload' do
      expect(worker).to receive(:log_extra_metadata_on_done)
        .with(:result, {
          reached_end_of_table: true, records_inserted: 1,
          worker_index: 0, total_workers: 1,
          min_build_id: build1.id, max_build_id: build1.id
        })

      params = { worker_index: 0, total_workers: 1 }
      expect_next_instance_of(::ClickHouse::DataIngestion::CiFinishedBuildsSyncService, params) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      expect(ClickHouse::Client).to receive(:insert_csv).once.and_call_original

      expect { perform }.to change { ci_finished_builds_row_count }.by(::Ci::Build.finished.count)
    end

    context 'when an error is reported from service' do
      before do
        allow(ClickHouse::Client.configuration).to receive(:databases).and_return({})
      end

      it 'skips execution' do
        expect(worker).to receive(:log_extra_metadata_on_done)
          .with(:result, { message: 'ClickHouse database is not configured', reason: :db_not_configured })

        perform
      end
    end
  end

  context 'with 2 workers' do
    using RSpec::Parameterized::TableSyntax

    subject(:perform) { worker.perform(worker_index, 2) }

    where(:worker_index) { [0, 1] }

    with_them do
      let(:params) { { worker_index: worker_index, total_workers: 2 } }

      it 'processes record if it falls on specified partition' do
        # select the records that fall in the specified partition
        partition_count = ClickHouse::DataIngestion::CiFinishedBuildsSyncService::BUILD_ID_PARTITIONS
        modulus_arel = Arel.sql("(build_id % #{partition_count})")
        lower_bound = (worker_index * partition_count / params[:total_workers]).to_i
        upper_bound = ((worker_index + 1) * partition_count / params[:total_workers]).to_i
        build_ids =
          Ci::FinishedBuildChSyncEvent
            .where(modulus_arel.gteq(lower_bound))
            .where(modulus_arel.lt(upper_bound))
            .map(&:build_id)

        expect(worker).to receive(:log_extra_metadata_on_done)
          .with(:result, {
            reached_end_of_table: true, records_inserted: build_ids.count,
            min_build_id: build_ids.min, max_build_id: build_ids.max
          }.merge(params))

        expect_next_instance_of(::ClickHouse::DataIngestion::CiFinishedBuildsSyncService, params) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        if build_ids.any?
          expect(ClickHouse::Client).to receive(:insert_csv).once.and_call_original
        else
          expect(ClickHouse::Client).not_to receive(:insert_csv)
        end

        perform
      end
    end
  end

  def create_sync_events(*builds)
    builds.each do |build|
      Ci::FinishedBuildChSyncEvent.new(build_id: build.id, build_finished_at: build.finished_at).save!
    end
  end

  def ci_finished_builds_row_count
    ClickHouse::Client.select('SELECT COUNT(*) AS count FROM ci_finished_builds', :main).first['count']
  end
end
