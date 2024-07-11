# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::TimeoutPendingStatusCheckResponsesWorker, feature_category: :compliance_management do
  describe "#perform" do
    let_it_be(:worker) { described_class.new }
    let_it_be(:old_pending_status_check_response, reload: true) { create(:old_pending_status_check_response) }
    let_it_be(:old_passed_status_check_response, reload: true) { create(:old_passed_status_check_response) }
    let_it_be(:old_failed_status_check_response, reload: true) { create(:old_failed_status_check_response) }
    let_it_be(:old_retried_pending_status_check_response, reload: true) do
      create(:old_retried_pending_status_check_response)
    end

    let_it_be(:recent_pending_status_check_response, reload: true) { create(:status_check_response, :pending) }
    let_it_be(:recent_retried_pending_status_check_response, reload: true) do
      create(:recent_retried_pending_status_check_response)
    end

    context 'when feature flag `timeout_status_check_responses` is enabled' do
      it 'sets qualified `pending` status check responses to failed' do
        worker.perform

        expect(recent_pending_status_check_response.status).to eq('pending')
        expect(recent_retried_pending_status_check_response.status).to eq('pending')

        expect(old_pending_status_check_response.status).to eq('failed')
        expect(old_retried_pending_status_check_response.status).to eq('failed')
      end

      it 'does not update existing `passed` or `failed` status check responses' do
        expect(old_passed_status_check_response.status).to eq('passed')
        expect(old_failed_status_check_response.status).to eq('failed')
      end
    end

    context 'when feature flag `timeout_status_check_responses` is disabled' do
      before do
        stub_feature_flags(timeout_status_check_responses: false)
      end

      it 'does not update status check responses' do
        worker.perform

        expect(recent_pending_status_check_response.status).to eq('pending')
        expect(recent_retried_pending_status_check_response.status).to eq('pending')
        expect(old_pending_status_check_response.status).to eq('pending')
        expect(old_retried_pending_status_check_response.status).to eq('pending')
      end
    end

    it_behaves_like 'an idempotent worker'
  end
end
