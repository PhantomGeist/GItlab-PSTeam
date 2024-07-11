# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Manually create a todo item from epic', :js, feature_category: :portfolio_management do
  let(:group) { create(:group) }
  let(:epic) { create(:epic, group: group) }
  let(:user) { create(:user, :no_super_sidebar) }
  let(:todo_selector) { '[data-testid="sidebar-todo"]' }

  context 'with notifications_todos_buttons feature flag disabled' do
    before do
      stub_licensed_features(epics: true)
      stub_feature_flags(notifications_todos_buttons: false)

      sign_in(user)
      visit group_epic_path(group, epic)
    end

    it 'creates todo when clicking button' do
      page.within '.issuable-sidebar' do
        click_button 'Add a to do'

        expect(page).to have_content 'Mark as done'
      end

      page.within ".header-content span[aria-label='#{_('Todos count')}']" do
        expect(page).to have_content '1'
      end
    end

    it 'marks a todo as done' do
      page.within '.issuable-sidebar' do
        click_button 'Add a to do'
      end

      expect(page).to have_selector(".header-content span[aria-label='#{_('Todos count')}']", visible: true)
      page.within ".header-content span[aria-label='#{_('Todos count')}']" do
        expect(page).to have_content '1'
      end

      page.within '.issuable-sidebar' do
        click_button 'Mark as done'
      end

      expect(page).to have_selector(".header-content span[aria-label='#{_('Todos count')}']", visible: false)
    end

    it 'passes axe automated accessibility testing for todo' do
      expect(page).to be_axe_clean.within(todo_selector)
    end
  end

  context 'with notifications_todos_buttons feature flag enabled' do
    before do
      stub_licensed_features(epics: true)
      stub_feature_flags(moved_mr_sidebar: true)
      stub_feature_flags(notifications_todos_buttons: true)

      sign_in(user)
      visit group_epic_path(group, epic)
    end

    it 'creates todo when clicking button' do
      page.within '.issuable-sidebar' do
        click_button 'Add a to do'
        wait_for_requests

        expect(page).to have_selector("button[title='Mark as done']")
      end

      page.within ".header-content span[aria-label='#{_('Todos count')}']" do
        expect(page).to have_content '1'
      end
    end

    it 'passes axe automated accessibility testing for todo' do
      expect(page).to be_axe_clean.within(todo_selector)
    end
  end
end
