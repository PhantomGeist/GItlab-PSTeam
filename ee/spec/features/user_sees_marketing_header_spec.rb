# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'User sees experimental marketing header', feature_category: :onboarding do
  let_it_be(:project) { create(:project, :public) }

  context 'when not logged in' do
    subject { page.find('.super-sidebar-logged-out') }

    it 'does not show marketing header links', :aggregate_failures do
      visit project_path(project)

      expect(subject).not_to have_text "Why GitLab"
      expect(subject).not_to have_text "Pricing"
      expect(subject).not_to have_text "Contact Sales"
      expect(subject).not_to have_text "Get free trial"

      expect(subject).to have_text "Explore"
      expect(subject).to have_text "Sign in"
      expect(subject).to have_text "Register"
    end

    context 'when SaaS', :saas do
      it 'shows marketing header links', :aggregate_failures do
        visit project_path(project)

        expect(subject).to have_text "Why GitLab"
        expect(subject).to have_text "Pricing"
        expect(subject).to have_text "Contact Sales"
        expect(subject).to have_text "Get free trial"
        expect(subject).to have_text "Explore"
        expect(subject).to have_text "Sign in"
        expect(subject).not_to have_text "Register"
      end
    end
  end

  context 'when logged in' do
    it 'does not show marketing header links', :aggregate_failures do
      sign_in(create(:user))

      visit project_path(project)

      expect(page).not_to have_selector('.super-sidebar-logged-out')
      expect(page).not_to have_text "About GitLab"
      expect(page).not_to have_text "Pricing"
      expect(page).not_to have_text "Talk to an expert"
      expect(page).not_to have_text "Register"
      expect(page).not_to have_text "Sign in"
    end
  end
end
