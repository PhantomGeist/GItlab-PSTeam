# frozen_string_literal: true

module QA
  include Support::Helpers::Plan

  RSpec.shared_examples 'Purchase storage' do |purchase_quantity|
    it 'adds additional storage to group namespace' do
      Flow::Purchase.purchase_storage(quantity: purchase_quantity)

      Gitlab::Page::Group::Settings::UsageQuotas.perform do |usage_quota|
        expected_storage = (STORAGE[:storage] * purchase_quantity).to_f

        expect { usage_quota.storage_purchase_successful_alert? }
          .to eventually_be_truthy.within(max_duration: 60, max_attempts: 30)
        expect { usage_quota.total_purchased_storage }
          .to eventually_eq(expected_storage).within(max_duration: 120, max_attempts: 60, reload_page: page)
      end
    end
  end

  RSpec.describe 'Fulfillment', :requires_admin, only: { subdomain: :staging }, product_group: :utilization,
    quarantine: {
      issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/422005',
      type: :stale
    } do
    let(:admin_api_client) { Runtime::API::Client.as_admin }
    let(:owner_api_client) { Runtime::API::Client.new(:gitlab, user: user) }
    let(:hash) { SecureRandom.hex(4) }

    let(:user) do
      create(:user, :hard_delete, email: "test-user-#{hash}@gitlab.com", api_client: admin_api_client)
    end

    let(:group) do
      Resource::Sandbox.fabricate_via_browser_ui! do |sandbox|
        sandbox.path = "test-group-fulfillment-#{hash}"
        sandbox.api_client = owner_api_client
      end
    end

    before do
      Flow::Login.sign_in(as: user)

      create(:project, :with_readme, name: 'storage', group: group, api_client: owner_api_client)

      group.visit!
    end

    after do
      user.remove_via_api!
    end

    context 'without active subscription',
      testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347571' do
      it_behaves_like 'Purchase storage', 5
    end

    context 'with an active subscription',
      testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348472' do
      before do
        Flow::Purchase.upgrade_subscription(plan: PREMIUM)

        Gitlab::Page::Group::Settings::Billing.perform do |billing|
          billing.wait_for_subscription(PREMIUM[:name])
        end
      end

      it_behaves_like 'Purchase storage', 20
    end

    context 'with existing compute minutes packs',
      testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348470' do
      let(:ci_purchase_quantity) { 5 }

      before do
        Flow::Purchase.purchase_compute_minutes(quantity: ci_purchase_quantity)

        Gitlab::Page::Group::Settings::UsageQuotas.perform do |usage_quota|
          usage_quota.wait_for_additional_compute_minute_limits(
            (COMPUTE_MINUTES[:compute_minutes] * ci_purchase_quantity).to_s
          )
        end
      end

      it_behaves_like 'Purchase storage', 10
    end
  end
end
