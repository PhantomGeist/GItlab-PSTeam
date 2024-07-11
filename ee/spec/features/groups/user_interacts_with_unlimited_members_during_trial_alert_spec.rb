# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group > Unlimited members alert', :js, :saas, feature_category: :groups_and_projects do
  include SubscriptionPortalHelpers

  let(:alert_selector) { '[data-testid="unlimited-members-during-trial-alert"]' }
  let_it_be(:group) { create(:group, :private, name: 'unlimited-members-during-trial-alert-group') }
  let_it_be(:subgroup) { create(:group, :private, parent: group, name: 'subgroup') }
  let_it_be(:user) { create(:user) }

  context 'when group not in trial' do
    it 'does not display alert' do
      group.add_owner(user)
      sign_in(user)

      visit group_path(group)

      expect_to_be_on_group_index_without_alert
    end
  end

  context 'when group is in trial' do
    before do
      create(:gitlab_subscription, :active_trial, namespace: group)

      stub_application_setting(dashboard_limit_enabled: true)
    end

    context 'when user is not owner' do
      it 'does not display alert' do
        group.add_maintainer(user)
        sign_in(user)

        visit group_path(group)

        expect_to_be_on_group_index_without_alert
      end
    end

    context 'when user is owner' do
      before do
        group.add_owner(user)

        sign_in(user)
      end

      it_behaves_like 'unlimited members during trial alert' do
        let_it_be(:members_page_path) { group_group_members_path(group) }
        let_it_be(:billings_page_path) { group_billings_path(group) }
        let_it_be(:page_path) { group_path(group) }
      end
    end

    context 'when group is subgroup' do
      before do
        group.add_owner(user)
        subgroup.add_owner(user)

        sign_in(user)
      end

      it_behaves_like 'unlimited members during trial alert' do
        let_it_be(:members_page_path) { group_group_members_path(subgroup) }
        let_it_be(:billings_page_path) { group_billings_path(group) }
        let_it_be(:page_path) { group_path(subgroup) }
      end

      it 'displays alert with Explore paid plans link and Invite more members button' do
        stub_application_setting(check_namespace_plan: true)
        stub_signing_key
        stub_subscription_management_data(group.id)
        stub_billing_plans(group.id)

        visit group_billings_path(subgroup)

        expect(page).to have_selector(alert_selector)
        expect(page).to have_link(text: 'Explore paid plans', href: group_billings_path(group))
        expect(page).to have_button('Invite more members')
      end
    end
  end

  def expect_to_be_on_group_index_without_alert
    expect(page).to have_content('Subgroups and projects')
    expect(page).not_to have_selector(alert_selector)
  end
end
