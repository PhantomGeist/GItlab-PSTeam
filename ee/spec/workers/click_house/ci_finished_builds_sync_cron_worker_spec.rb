# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::CiFinishedBuildsSyncCronWorker, :click_house, :freeze_time, feature_category: :runner_fleet do
  let(:worker) { described_class.new }

  subject(:perform) { worker.perform(*args) }

  include_examples 'an idempotent worker' do
    context 'when job version is nil' do
      before do
        allow(worker).to receive(:job_version).and_return(nil)
      end

      context 'when arguments are not specified' do
        let(:args) { [] }

        it 'does nothing' do
          expect(ClickHouse::CiFinishedBuildsSyncWorker).not_to receive(:perform_async)

          perform
        end
      end

      context 'when arguments are specified' do
        let(:args) { [worker_index, total_workers] }

        context 'with total_workers set to 3' do
          let(:total_workers) { 3 }

          context 'with worker_index set to 0' do
            let(:worker_index) { 0 }

            it 'does nothing' do
              expect(ClickHouse::CiFinishedBuildsSyncWorker).not_to receive(:perform_async)

              perform
            end
          end
        end
      end
    end

    context 'when job version is present' do
      context 'when arguments are not specified' do
        let(:args) { [] }

        it 'invokes 1 worker with specified arguments' do
          expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(0, 1)

          perform
        end
      end

      context 'when arguments are specified' do
        let(:args) { [total_workers] }

        context 'with total_workers set to 1' do
          let(:total_workers) { 1 }

          it 'invokes 1 worker' do
            expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(0, 1)

            perform
          end
        end

        context 'with total_workers set to 3', :aggregate_failures do
          let(:total_workers) { 3 }

          it 'invokes 3 workers' do
            expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(0, 3)
            expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(1, 3)
            expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(2, 3)

            perform
          end
        end
      end
    end
  end
end
