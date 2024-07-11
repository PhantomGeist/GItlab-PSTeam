# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::UsersController, :enable_admin_mode, feature_category: :user_management do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  before do
    sign_in(admin)
  end

  describe 'GET card_match' do
    context 'when not SaaS' do
      it 'responds with 404' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when SaaS', :saas do
      context 'when user has no credit card validation' do
        it 'redirects back to #show' do
          send_request

          expect(response).to redirect_to(admin_user_path(user))
        end
      end

      context 'when user has credit card validation' do
        let_it_be(:credit_card_validation) { create(:credit_card_validation, user: user) }
        let_it_be(:card_details) do
          credit_card_validation.attributes.slice(:expiration_date, :last_digits, :holder_name)
        end

        let_it_be(:match) { create(:credit_card_validation, card_details) }

        it 'displays its own and matching card details', :aggregate_failures do
          send_request

          expect(response).to have_gitlab_http_status(:ok)

          expect(response.body).to include(match.user.id.to_s)
          expect(response.body).to include(match.user.username)
          expect(response.body).to include(match.user.name)
          expect(response.body).to include(match.credit_card_validated_at.to_fs(:medium))
          expect(response.body).to include(match.user.created_at.to_fs(:medium))
        end
      end
    end

    def send_request
      get card_match_admin_user_path(user)
    end
  end

  describe 'GET #index' do
    it 'eager loads authorized projects association' do
      get admin_users_path

      expect(assigns(:users).first.association(:user_highest_role)).to be_loaded
      expect(assigns(:users).first.association(:elevated_members)).to be_loaded
    end
  end

  describe 'PATCH #update' do
    context 'when user is an enterprise user' do
      let(:user) { create(:user, :enterprise_user) }

      context "when new email is not owned by the user's enterprise group" do
        let(:new_email) { 'new-email@example.com' }

        # See https://gitlab.com/gitlab-org/gitlab/-/issues/412762
        it 'allows change user email', :aggregate_failures do
          expect { patch admin_user_path(user), params: { user: { email: new_email } } }
            .to change { user.reload.email }.from(user.email).to(new_email)

          expect(response).to redirect_to(admin_user_path(user))
          expect(flash[:notice]).to eq('User was successfully updated.')
        end
      end
    end
  end

  describe 'PUT #unlock' do
    before do
      user.lock_access!
    end

    subject(:request) { put unlock_admin_user_path(user) }

    it 'logs a user_access_unlock audit event with author set to the current user' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(
          name: 'user_access_unlocked',
          author: admin
        )
      ).and_call_original

      expect { request }.to change { user.reload.access_locked? }.from(true).to(false)
    end
  end
end
