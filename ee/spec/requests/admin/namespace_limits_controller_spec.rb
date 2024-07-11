# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::NamespaceLimitsController, :enable_admin_mode,
  type: :request,
  feature_category: :consumables_cost_management do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  describe 'GET #index', :aggregate_failures do
    subject(:get_index) { get admin_namespace_limits_path }

    shared_examples 'not found' do
      it 'is not found' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with an admin user' do
      before do
        sign_in(admin)
      end

      context 'when on .com', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        it 'is successful' do
          get_index

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when not on .com' do
        it_behaves_like 'not found'
      end
    end

    context 'with non-admin user' do
      before do
        sign_in(user)
      end

      it_behaves_like 'not found'
    end

    context 'when no user is logged in' do
      it 'redirects to login page' do
        get_index

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end
  end

  describe 'GET #export_usage', :aggregate_failures do
    context 'when signed in' do
      context 'with an admin user' do
        before do
          sign_in(admin)
        end

        context 'when requesting CSV format' do
          context 'when on .com', :saas do
            before do
              stub_ee_application_setting(should_check_namespace_plan: true)
            end

            subject(:get_export) { get admin_namespace_limits_export_usage_path }

            it 'enqueues the CSV generation', :freeze_time do
              expect(Namespaces::StorageUsageExportWorker).to receive(:perform_async).with('free', admin.id)

              get_export

              expect(response).to redirect_to admin_namespace_limits_path
              expect(flash[:notice]).to eq('CSV is being generated and will be emailed to you upon completion.')
            end
          end
        end
      end
    end

    context 'when no user is logged in' do
      it 'redirects to login page' do
        get admin_namespace_limits_export_usage_path

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end
  end
end
