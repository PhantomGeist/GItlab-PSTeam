# frozen_string_literal: true
require 'spec_helper'

RSpec.describe ApplicationController, type: :request, feature_category: :shared do
  context 'with redirection due to onboarding', feature_category: :onboarding do
    let(:onboarding_in_progress) { true }
    let(:url) { '_onboarding_step_' }

    let(:user) do
      create(:user, role: nil, onboarding_in_progress: onboarding_in_progress).tap do |record|
        create(:user_detail, user: record, onboarding_step_url: url)
      end
    end

    before do
      sign_in(user)
    end

    context 'when on SaaS', :saas do
      it 'redirects to the onboarding step' do
        get root_path

        expect(response).to redirect_to(url)
      end

      context 'when qualifying for 2fa' do
        it 'redirects to the onboarding step' do
          create_two_factor_group_with_user(user)

          get root_path

          expect(response).to redirect_to(url)
        end
      end

      context 'when onboarding is disabled' do
        let(:onboarding_in_progress) { false }

        it 'does not redirect to the onboarding step' do
          get root_path

          expect(response).not_to be_redirect
        end

        context 'when qualifying for 2fa' do
          it 'redirects to 2fa setup' do
            create_two_factor_group_with_user(user)

            get root_path

            expect(response).to redirect_to(profile_two_factor_auth_path)
          end
        end
      end

      context 'when request path equals redirect path' do
        let(:url) { root_path }

        it 'does not redirect to the onboarding step' do
          get root_path

          expect(response).not_to be_redirect
        end
      end

      context 'with non-get request' do
        it 'does not redirect to the onboarding step' do
          expect_next_instance_of(GitlabSubscriptions::CreateLeadService) do |instance|
            expect(instance).to receive(:execute).and_return(ServiceResponse.success)
          end

          post users_sign_up_company_path
        end
      end
    end

    context 'when on not on SaaS' do
      it 'redirects to the onboarding step' do
        get root_path

        expect(response).not_to be_redirect
      end

      context 'when qualifying for 2fa' do
        it 'redirects to 2fa setup' do
          create_two_factor_group_with_user(user)

          get root_path

          expect(response).to redirect_to(profile_two_factor_auth_path)
        end
      end
    end

    def create_two_factor_group_with_user(user)
      create(:group, require_two_factor_authentication: true).tap do |g|
        g.add_developer(user)
        user.reset
      end
    end
  end
end
