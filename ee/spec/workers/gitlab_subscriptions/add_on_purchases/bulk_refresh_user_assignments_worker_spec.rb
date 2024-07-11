# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::BulkRefreshUserAssignmentsWorker, :saas, feature_category: :seat_cost_management do
  describe '#perform_work' do
    subject(:perform_work) { described_class.new.perform_work }

    before do
      stub_ee_application_setting(check_namespace_plan: true)
    end

    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:add_on_purchase_fresh) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.hour.ago)
    end

    before_all do
      add_on_purchase_fresh.assigned_users.create!(user: create(:user))
    end

    shared_examples 'returns early' do
      it 'does not remove assigned users' do
        expect(Gitlab::AppLogger).not_to receive(:info)

        expect do
          perform_work
        end.not_to change { GitlabSubscriptions::UserAddOnAssignment.count }
      end
    end

    context 'when there are stale add_on_purchases' do
      let_it_be(:add_on_purchase_stale) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.day.ago)
      end

      before_all do
        add_on_purchase_stale.assigned_users.create!(user: create(:user))
      end

      describe 'idempotence' do
        include_examples 'an idempotent worker' do
          it 'refreshes assigned_users for stale add_on_purchases' do
            expect do
              perform_work
            end.to change { GitlabSubscriptions::UserAddOnAssignment.count }.by(-1)
              .and change { add_on_purchase_stale.reload.last_assigned_users_refreshed_at }

            expect(add_on_purchase_fresh.assigned_users.count).to eq(1)
          end
        end
      end

      it 'logs info when assignments are refreshed' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'AddOnPurchase user assignments refreshed via scheduled CronJob',
          deleted_assignments_count: 1,
          add_on: add_on_purchase_stale.add_on.name,
          namespace: add_on_purchase_stale.namespace.path
        )

        perform_work
      end

      context 'when not on GitLab.com' do
        before do
          stub_ee_application_setting(check_namespace_plan: false)
        end

        it_behaves_like 'returns early'
      end

      context 'when feature flag bulk_add_on_assignment_refresh_worker is disabled' do
        before do
          stub_feature_flags(bulk_add_on_assignment_refresh_worker: false)
        end

        it_behaves_like 'returns early'
      end
    end

    context 'when there are no stale add_on_purchase to refresh' do
      it_behaves_like 'returns early'
    end
  end

  describe '#max_running_jobs' do
    it 'returns constant value' do
      expect(subject.max_running_jobs).to eq(described_class::MAX_RUNNING_JOBS)
    end
  end

  describe '#remaining_work_count' do
    before_all do
      add_on = create(:gitlab_subscription_add_on)
      3.times do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.day.ago)
      end
    end

    context 'when there is remaining work' do
      before do
        stub_const("#{described_class}::MAX_RUNNING_JOBS", 1)
      end

      it 'returns correct amount' do
        expect(subject.remaining_work_count).to eq(2)
      end

      context 'when the bulk_add_on_assignment_refresh_worker FF is disabled' do
        before do
          stub_feature_flags(bulk_add_on_assignment_refresh_worker: false)
        end

        it 'returns zero' do
          expect(subject.remaining_work_count).to eq(0)
        end
      end
    end

    context 'when there is no remaining work' do
      before do
        GitlabSubscriptions::AddOnPurchase.update_all(last_assigned_users_refreshed_at: Time.current)
      end

      it 'returns zero' do
        expect(subject.remaining_work_count).to eq(0)
      end
    end
  end
end
