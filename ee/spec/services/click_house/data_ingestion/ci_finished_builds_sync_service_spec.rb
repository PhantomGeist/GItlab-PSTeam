# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::DataIngestion::CiFinishedBuildsSyncService,
  :click_house, feature_category: :runner_fleet do
  subject(:execute) { service.execute }

  let(:service) { described_class.new }

  let_it_be(:runner) { create(:ci_runner) }
  let_it_be(:runner_manager1) do
    create(:ci_runner_machine, runner: runner, version: '16.4.0', revision: 'abc', platform: 'linux',
      architecture: 'amd64')
  end

  let_it_be(:build1) { create(:ci_build, :success, runner_manager: runner_manager1) }
  let_it_be(:build2) { create(:ci_build, :canceled) }
  let_it_be(:build3) { create(:ci_build, :failed) }
  let_it_be(:build4) { create(:ci_build, :pending) }

  before_all do
    create_sync_events(*Ci::Build.finished.order(id: :desc))
  end

  context 'when the ci_data_ingestion_to_click_house feature flag is on' do
    before do
      stub_feature_flags(ci_data_ingestion_to_click_house: true)
    end

    context 'when all builds fit in a single batch' do
      it 'processes the builds' do
        expect(ClickHouse::Client).to receive(:insert_csv).once.and_call_original

        expect { execute }.to change { ci_finished_builds_row_count }.by(3)
        expect(execute).to have_attributes({
          payload: {
            reached_end_of_table: true,
            records_inserted: 3,
            worker_index: 0, total_workers: 1,
            min_build_id: build1.id,
            max_build_id: build3.id
          }
        })

        records = ci_finished_builds
        expect(records.count).to eq 3
        expect(records).to contain_exactly(
          a_hash_including(**expected_build_attributes(build1)),
          a_hash_including(**expected_build_attributes(build2)),
          a_hash_including(**expected_build_attributes(build3))
        )
      end

      it 'processes only builds from Ci::FinishedBuildChSyncEvent' do
        build = create(:ci_build, :failed)

        expect { execute }.to change { ci_finished_builds_row_count }.by(3)
        expect(execute).to have_attributes({
          payload: a_hash_including(reached_end_of_table: true, records_inserted: 3)
        })

        create_sync_events(build)
        expect { service.execute }.to change { ci_finished_builds_row_count }.by(1)
      end

      context 'when a finished build has nil finished_at value' do
        it 'skips the build' do
          create(:ci_build, :failed, finished_at: nil)

          expect { execute }.to change { ci_finished_builds_row_count }.by(3)
          records = ci_finished_builds
          expect(records.count).to eq 3
          expect(records).to contain_exactly(
            a_hash_including(**expected_build_attributes(build1)),
            a_hash_including(**expected_build_attributes(build2)),
            a_hash_including(**expected_build_attributes(build3))
          )
        end
      end

      context 'when a finished build has been deleted' do
        it 'marks the sync event as processed' do
          sync_event = Ci::FinishedBuildChSyncEvent
            .new(build_id: non_existing_record_id, build_finished_at: Time.current)
            .tap(&:save!)

          expect { execute }
            .to change { ci_finished_builds_row_count }.by(3)
            .and change { sync_event.reload.processed }.to(true)
        end
      end
    end

    context 'when multiple batches are required' do
      before do
        stub_const("#{described_class}::BUILDS_BATCH_SIZE", 2)
      end

      it 'processes the builds' do
        expect(ClickHouse::Client).to receive(:insert_csv).once.and_call_original

        expect { execute }.to change { ci_finished_builds_row_count }.by(3)
        expect(execute).to have_attributes({
          payload: a_hash_including(reached_end_of_table: true, records_inserted: 3)
        })
      end
    end

    context 'when multiple CSV uploads are required' do
      before do
        stub_const("#{described_class}::BUILDS_BATCH_SIZE", 1)
        stub_const("#{described_class}::BUILDS_BATCH_COUNT", 2)
      end

      it 'processes the builds' do
        expect_next_instance_of(Gitlab::Pagination::Keyset::Iterator) do |iterator|
          expect(iterator).to receive(:each_batch).once.with(of: described_class::BUILDS_BATCH_SIZE).and_call_original
        end

        expect(ClickHouse::Client).to receive(:insert_csv).twice.and_call_original

        expect { execute }.to change { ci_finished_builds_row_count }.by(3)
        expect(execute).to have_attributes({
          payload: a_hash_including(reached_end_of_table: true, records_inserted: 3)
        })
      end

      context 'with time limit being reached' do
        it 'processes the builds of the first batch' do
          over_time = false

          expect_next_instance_of(Analytics::CycleAnalytics::RuntimeLimiter) do |limiter|
            expect(limiter).to receive(:over_time?).at_least(1) { over_time }
          end

          expect(service).to receive(:yield_builds).and_wrap_original do |original, *args|
            over_time = true
            original.call(*args)
          end

          expect { execute }.to change { ci_finished_builds_row_count }.by(described_class::BUILDS_BATCH_SIZE)
          expect(execute).to have_attributes({
            payload: a_hash_including(
              reached_end_of_table: false, records_inserted: described_class::BUILDS_BATCH_SIZE,
              min_build_id: build1.id, max_build_id: build1.id
            )
          })
        end
      end

      context 'when batches fail to be written to ClickHouse' do
        it 'does not mark any records as processed' do
          expect(ClickHouse::Client).to receive(:insert_csv) { raise ClickHouse::Client::DatabaseError }

          expect { execute }.to raise_error(ClickHouse::Client::DatabaseError)
            .and not_change { Ci::FinishedBuildChSyncEvent.pending.count }
        end
      end
    end

    context 'with multiple calls to service' do
      it 'processes the builds' do
        expect_next_instances_of(Gitlab::Pagination::Keyset::Iterator, 2) do |iterator|
          expect(iterator).to receive(:each_batch).once.with(of: described_class::BUILDS_BATCH_SIZE).and_call_original
        end

        expect { execute }.to change { ci_finished_builds_row_count }.by(3)
        expect(execute).to have_attributes({
          payload: a_hash_including(reached_end_of_table: true, records_inserted: 3)
        })

        build5 = create(:ci_build, :failed)
        create_sync_events(build5)

        expect { service.execute }.to change { ci_finished_builds_row_count }.by(1)
        records = ci_finished_builds
        expect(records.count).to eq 4
        expect(records).to contain_exactly(
          a_hash_including(**expected_build_attributes(build1)),
          a_hash_including(**expected_build_attributes(build2)),
          a_hash_including(**expected_build_attributes(build3)),
          a_hash_including(**expected_build_attributes(build5))
        )
      end

      context 'with same updated_at value' do
        it 'processes the builds' do
          expect { service.execute }.to change { ci_finished_builds_row_count }.by(3)

          build5 = create(:ci_build, :failed)
          build6 = create(:ci_build, :failed)
          create_sync_events(build5, build6)

          expect { execute }.to change { ci_finished_builds_row_count }.by(2)
          expect(execute).to have_attributes({
            payload: a_hash_including(min_build_id: build5.id, max_build_id: build6.id)
          })

          records = ci_finished_builds
          expect(records.count).to eq 5
          expect(records).to contain_exactly(
            a_hash_including(**expected_build_attributes(build1)),
            a_hash_including(**expected_build_attributes(build2)),
            a_hash_including(**expected_build_attributes(build3)),
            a_hash_including(**expected_build_attributes(build5)),
            a_hash_including(**expected_build_attributes(build6))
          )
        end
      end

      context 'with older finished_at value' do
        it 'does not process the build' do
          expect { service.execute }.to change { ci_finished_builds_row_count }.by(3)

          create(:ci_build, :failed)

          expect { service.execute }.not_to change { ci_finished_builds_row_count }
        end
      end
    end

    context 'when no ClickHouse databases are configured' do
      before do
        allow(ClickHouse::Client.configuration).to receive(:databases).and_return({})
      end

      it 'skips execution' do
        is_expected.to have_attributes({
          status: :error,
          message: 'ClickHouse database is not configured',
          reason: :db_not_configured,
          payload: { worker_index: 0, total_workers: 1 }
        })
      end
    end

    context 'when exclusive lease error happens' do
      context 'when the exclusive lease is already locked for the worker' do
        let(:service) { described_class.new(worker_index: 2, total_workers: 3) }

        before do
          lock_name = "#{described_class.name.underscore}/worker/2"
          allow(service).to receive(:in_lock).with(lock_name, retries: 0, ttl: 360)
            .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
        end

        it 'does nothing' do
          expect { execute }.not_to change { ci_finished_builds_row_count }

          expect(execute).to have_attributes({
            status: :error, reason: :skipped, payload: { worker_index: 2, total_workers: 3 }
          })
        end
      end
    end
  end

  context 'when the ci_data_ingestion_to_click_house feature flag is off' do
    before do
      stub_feature_flags(ci_data_ingestion_to_click_house: false)
    end

    it 'skips execution' do
      is_expected.to have_attributes({
        status: :error,
        message: 'Feature ci_data_ingestion_to_click_house is disabled',
        reason: :disabled,
        payload: { worker_index: 0, total_workers: 1 }
      })
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

  def ci_finished_builds
    ClickHouse::Client
      .select('SELECT * FROM ci_finished_builds', :main)
      .map(&:symbolize_keys)
  end

  def expected_build_attributes(build)
    runner = build.runner
    runner_manager = build.runner_manager

    {
      id: build.id, status: build.status, project_id: build.project_id, pipeline_id: build.pipeline_id,
      created_at: a_value_within(1.second).of(build.created_at),
      started_at: a_value_within(1.second).of(build.started_at),
      queued_at: a_value_within(1.second).of(build.queued_at),
      finished_at: a_value_within(1.second).of(build.finished_at),
      runner_id: runner&.id || 0,
      runner_type: Ci::Runner.runner_types.fetch(runner&.runner_type, 0),
      runner_run_untagged: runner&.run_untagged || false,
      runner_manager_system_xid: runner_manager&.system_xid || '',
      runner_manager_version: runner_manager&.version || '',
      runner_manager_revision: runner_manager&.revision || '',
      runner_manager_platform: runner_manager&.platform || '',
      runner_manager_architecture: runner_manager&.architecture || ''
    }
  end
end
