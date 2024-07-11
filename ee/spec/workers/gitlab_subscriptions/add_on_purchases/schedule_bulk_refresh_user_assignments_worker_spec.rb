# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::ScheduleBulkRefreshUserAssignmentsWorker, feature_category: :seat_cost_management do
  describe '#perform' do
    let(:worker_class) { GitlabSubscriptions::AddOnPurchases::BulkRefreshUserAssignmentsWorker }

    before do
      stub_ee_application_setting(check_namespace_plan: true)
    end

    describe 'idempotence' do
      include_examples 'an idempotent worker' do
        it 'schedules ScheduleBulkRefreshUserAssignmentsWorker' do
          expect(worker_class).to receive(:perform_with_capacity).twice

          subject
        end
      end
    end

    context 'when not on GitLab.com' do
      before do
        stub_ee_application_setting(check_namespace_plan: false)
      end

      it 'does not schedule a worker to perform with capacity' do
        expect(worker_class).not_to receive(:perform_with_capacity)

        subject.perform
      end
    end

    context 'when feature flag bulk_add_on_assignment_refresh_worker is disabled' do
      before do
        stub_feature_flags(bulk_add_on_assignment_refresh_worker: false)
      end

      it 'does not schedule the worker' do
        expect(worker_class).not_to receive(:perform_with_capacity)

        subject.perform
      end
    end
  end
end
