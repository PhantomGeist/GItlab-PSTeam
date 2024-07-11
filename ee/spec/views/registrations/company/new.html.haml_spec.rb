# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'registrations/company/new', feature_category: :onboarding do
  let(:user) { build_stubbed(:user) }
  let(:trial?) { false }
  let(:onboarding_status) { instance_double(::Onboarding::Status, trial?: trial?) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:onboarding_status).and_return(onboarding_status)
  end

  describe 'Google Tag Manager' do
    let!(:gtm_id) { 'GTM-WWKMTWS' }
    let!(:google_url) { 'www.googletagmanager.com' }

    subject { rendered }

    before do
      stub_devise
      stub_config(extra: { google_tag_manager_id: gtm_id, google_tag_manager_nonce_id: gtm_id })
      allow(view).to receive(:google_tag_manager_enabled?).and_return(gtm_enabled)

      render
    end

    describe 'when Google Tag Manager is enabled' do
      let(:gtm_enabled) { true }

      it { is_expected.to match(/#{google_url}/) }
    end

    describe 'when Google Tag Manager is disabled' do
      let(:gtm_enabled) { false }

      it { is_expected.not_to match(/#{google_url}/) }
    end
  end

  describe 'when page is rendered' do
    context 'when a user is coming from a trial registration' do
      let(:trial?) { true }

      it 'renders correctly' do
        render

        expect_to_see_trial_column
      end
    end

    context 'when a user is coming from a free registration' do
      let(:trial?) { false }

      it 'renders correctly' do
        render

        expect_to_see_registration_column
      end
    end
  end

  def stub_devise
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:resource).and_return(spy)
    allow(view).to receive(:resource_name).and_return(:user)
  end

  def expect_to_see_trial_column
    expect(rendered).to have_content(_('About your company'))
    expect(rendered).to have_selector('[data-testid="trial-registration-column"]')
  end

  def expect_to_see_registration_column
    expect(rendered).to have_content(_('About your company'))
    expect(rendered).to have_selector('[data-testid="trial-reassurances-column"]')
  end
end
