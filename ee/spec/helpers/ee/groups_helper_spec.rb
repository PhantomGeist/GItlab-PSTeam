# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupsHelper, feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  let(:owner) { create(:user, group_view: :security_dashboard) }
  let(:current_user) { owner }
  let(:group) { create(:group, :private) }

  before do
    allow(helper).to receive(:current_user) { current_user }
    helper.instance_variable_set(:@group, group)

    group.add_owner(owner)
  end

  describe '#render_setting_to_allow_project_access_token_creation?' do
    context 'with self-managed' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:group) { create(:group, parent: parent) }

      before do
        parent.add_owner(owner)
        group.add_owner(owner)
      end

      it 'returns true if group is root' do
        expect(helper.render_setting_to_allow_project_access_token_creation?(parent)).to eq(true)
      end

      it 'returns false if group is subgroup' do
        expect(helper.render_setting_to_allow_project_access_token_creation?(group)).to eq(false)
      end
    end

    context 'on .com', :saas do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'with a free plan' do
        let_it_be(:group) { create(:group) }

        it 'returns false' do
          expect(helper.render_setting_to_allow_project_access_token_creation?(group)).to eq(false)
        end
      end

      context 'with a paid plan' do
        let_it_be(:parent) { create(:group_with_plan, plan: :bronze_plan) }
        let_it_be(:group) { create(:group, parent: parent) }

        before do
          parent.add_owner(owner)
        end

        it 'returns true if group is root' do
          expect(helper.render_setting_to_allow_project_access_token_creation?(parent)).to eq(true)
        end

        it 'returns false if group is subgroup' do
          expect(helper.render_setting_to_allow_project_access_token_creation?(group)).to eq(false)
        end
      end
    end
  end

  describe '#permanent_deletion_date' do
    let(:date) { 2.days.from_now }

    subject { helper.permanent_deletion_date(date) }

    before do
      stub_application_setting(deletion_adjourned_period: 5)
    end

    it 'returns the sum of the date passed as argument and the deletion_adjourned_period set in application setting' do
      expected_date = date + 5.days

      expect(subject).to eq(expected_date.strftime('%F'))
    end
  end

  describe '#remove_group_message' do
    subject { helper.remove_group_message(group) }

    shared_examples 'permanent deletion message' do
      it 'returns the message related to permanent deletion' do
        expect(subject).to include("You are going to remove #{group.name}")
        expect(subject).to include("Removed groups CANNOT be restored!")
      end
    end

    shared_examples 'delayed deletion message' do
      it 'returns the message related to delayed deletion' do
        expect(subject).to include("The contents of this group, its subgroups and projects will be permanently removed after")
      end
    end

    context 'delayed deletion feature is available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      it_behaves_like 'delayed deletion message'

      context 'group is already marked for deletion' do
        before do
          create(:group_deletion_schedule, group: group, marked_for_deletion_on: Date.current)
        end

        it_behaves_like 'permanent deletion message'
      end

      context 'when group delay deletion is enabled' do
        before do
          stub_application_setting(delayed_group_deletion: true)
        end

        it_behaves_like 'delayed deletion message'
      end

      context 'when group delay deletion is disabled' do
        before do
          stub_application_setting(delayed_group_deletion: false)
        end

        it_behaves_like 'delayed deletion message'
      end

      context 'when group delay deletion is enabled and adjourned deletion period is 0' do
        before do
          stub_application_setting(delayed_group_deletion: true)
          stub_application_setting(deletion_adjourned_period: 0)
        end

        it_behaves_like 'permanent deletion message'
      end
    end

    context 'delayed deletion feature is not available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      end

      it_behaves_like 'permanent deletion message'
    end
  end

  describe '#immediately_remove_group_message' do
    subject { helper.immediately_remove_group_message(group) }

    it 'returns the message related to immediate deletion' do
      expect(subject).to match(/permanently remove.*#{group.path}.*immediately/)
    end
  end

  describe '#show_discover_group_security?' do
    using RSpec::Parameterized::TableSyntax

    where(
      gitlab_com?: [true, false],
      user?: [true, false],
      security_dashboard_feature_available?: [true, false],
      can_admin_group?: [true, false]
    )

    with_them do
      it 'returns the expected value' do
        allow(helper).to receive(:current_user) { user? ? owner : nil }
        allow(::Gitlab).to receive(:com?) { gitlab_com? }
        allow(group).to receive(:licensed_feature_available?) { security_dashboard_feature_available? }
        allow(helper).to receive(:can?) { can_admin_group? }

        expected_value = user? && gitlab_com? && !security_dashboard_feature_available? && can_admin_group?

        expect(helper.show_discover_group_security?(group)).to eq(expected_value)
      end
    end
  end

  describe '#show_group_activity_analytics?' do
    before do
      stub_licensed_features(group_activity_analytics: feature_available)

      allow(helper).to receive(:current_user) { current_user }
      allow(helper).to receive(:can?) { |*args| Ability.allowed?(*args) }
    end

    context 'when feature is not available for group' do
      let(:feature_available) { false }

      it 'returns false' do
        expect(helper.show_group_activity_analytics?).to be false
      end
    end

    context 'when current user does not have access to the group' do
      let(:feature_available) { true }
      let(:current_user) { create(:user) }

      it 'returns false' do
        expect(helper.show_group_activity_analytics?).to be false
      end
    end

    context 'when feature is available and user has access to it' do
      let(:feature_available) { true }

      it 'returns true' do
        expect(helper.show_group_activity_analytics?).to be true
      end
    end
  end

  describe '#show_product_purchase_success_alert?' do
    describe 'when purchased_product is present' do
      before do
        allow(controller).to receive(:params) { { purchased_product: product } }
      end

      where(:product, :result) do
        'product' | true
        ''        | false
        nil       | false
      end

      with_them do
        it { expect(helper.show_product_purchase_success_alert?).to be result }
      end
    end

    describe 'when purchased_product is not present' do
      it { expect(helper.show_product_purchase_success_alert?).to be false }
    end
  end

  describe '#group_seats_usage_quota_app_data' do
    subject(:group_seats_usage_quota_app_data) { helper.group_seats_usage_quota_app_data(group) }

    let(:user_cap_applied) { true }
    let(:enforcement_free_user_cap) { false }
    let(:data) do
      {
        namespace_id: group.id,
        namespace_name: group.name,
        full_path: group.full_path,
        seat_usage_export_path: group_seat_usage_path(group, format: :csv),
        pending_members_page_path: pending_members_group_usage_quotas_path(group),
        pending_members_count: ::Member.in_hierarchy(group).with_state("awaiting").count,
        add_seats_href: ::Gitlab::Routing.url_helpers.subscription_portal_add_extra_seats_url(group.id),
        has_no_subscription: group.has_free_or_no_subscription?.to_s,
        max_free_namespace_seats: 10,
        explore_plans_path: group_billings_path(group),
        enforcement_free_user_cap_enabled: 'false'
      }
    end

    before do
      stub_ee_application_setting(dashboard_limit: 10)
      expect(group).to receive(:user_cap_available?).and_return(user_cap_applied)

      expect_next_instance_of(::Namespaces::FreeUserCap::Enforcement, group) do |instance|
        expect(instance).to receive(:enforce_cap?).and_return(enforcement_free_user_cap)
      end
    end

    context 'when user cap is applied' do
      let(:expected_data) { data.merge({ pending_members_page_path: pending_members_group_usage_quotas_path(group) }) }

      it { is_expected.to eql(expected_data) }
    end

    context 'when user cap is not applied' do
      let(:user_cap_applied) { false }
      let(:expected_data) { data.merge({ pending_members_page_path: nil }) }

      it { is_expected.to eql(expected_data) }
    end

    context 'when free user cap is enforced' do
      let(:enforcement_free_user_cap) { true }
      let(:expected_data) { data.merge({ enforcement_free_user_cap_enabled: 'true' }) }

      it { is_expected.to eql(expected_data) }
    end
  end

  describe '#code_suggestions_usage_app_data' do
    subject(:code_suggestions_usage_app_data) { helper.code_suggestions_usage_app_data(group) }

    let(:data) do
      {
        full_path: group.full_path
      }
    end

    context 'when cs_connect_with_sales ff is disabled' do
      before do
        stub_feature_flags(cs_connect_with_sales: false)
      end

      it { is_expected.to eql(data) }
    end

    context 'when cs_connect_with_sales ff is enabled' do
      it 'contains data for hand raise lead button' do
        hand_raise_lead_button_data = helper.code_suggestions_hand_raise_props(group)

        expect(subject).to eq(data.merge(hand_raise_lead_button_data))
      end
    end
  end

  describe '#hand_raise_props' do
    let_it_be(:user) { create(:user, username: 'Joe', first_name: 'Joe', last_name: 'Doe', organization: 'ACME') }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'builds correct hash' do
      props = helper.hand_raise_props(group, glm_content: 'some-content')

      expect(props).to eq(
        namespace_id: group.id,
        user_name: 'Joe',
        first_name: 'Joe',
        last_name: 'Doe',
        company_name: 'ACME',
        glm_content: 'some-content',
        product_interaction: 'Hand Raise PQL',
        create_hand_raise_lead_path: '/-/subscriptions/hand_raise_leads')
    end

    it 'allows overriding of the default product_interaction' do
      props = helper.hand_raise_props(group, glm_content: 'some-content', product_interaction: '_product_interaction_')

      expect(props).to include(product_interaction: '_product_interaction_')
    end
  end

  describe '#code_suggestions_hand_raise_props' do
    let(:user) { build(:user, username: 'Joe', first_name: 'Joe', last_name: 'Doe', organization: 'ACME') }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'builds correct hash' do
      expected_result = {
        namespace_id: group.id,
        user_name: 'Joe',
        first_name: 'Joe',
        last_name: 'Doe',
        company_name: 'ACME',
        glm_content: 'code-suggestions',
        product_interaction: 'Requested Contact-Code Suggestions Add-On',
        create_hand_raise_lead_path: '/-/subscriptions/hand_raise_leads',
        track_action: 'click_button',
        track_label: 'code_suggestions_hand_raise_lead_form',
        button_attributes: { 'data-testid': 'code_suggestions_hand_raise_lead_button' }.to_json
      }

      props = helper.code_suggestions_hand_raise_props(group)

      expect(props).to eq(expected_result)
    end
  end

  describe '#show_code_suggestions_tab?' do
    describe 'when hamilton_seat_management is enabled' do
      where(:has_free_or_no_subscription?, :gitlab_com?, :result) do
        true  | true  | false
        true  | false | false
        false | false | false
        false | true  | true
      end

      with_them do
        it 'returns the expected value' do
          allow(::Gitlab).to receive(:com?) { gitlab_com? }
          allow(group).to receive(:has_free_or_no_subscription?) { has_free_or_no_subscription? }

          expect(helper.show_code_suggestions_tab?(group)).to eq(result)
        end
      end
    end

    describe 'when hamilton_seat_management is disabled' do
      before do
        stub_feature_flags(hamilton_seat_management: false)
      end

      where(:has_free_or_no_subscription?, :gitlab_com?, :result) do
        true  | true  | false
        true  | false | false
        false | false | false
        false | true  | false
      end

      with_them do
        it 'returns the expected value' do
          allow(::Gitlab).to receive(:com?) { gitlab_com? }
          allow(group).to receive(:has_free_or_no_subscription?) { has_free_or_no_subscription? }

          expect(helper.show_code_suggestions_tab?(group)).to eq(result)
        end
      end
    end
  end

  describe '#show_product_analytics_usage_quota_tab?' do
    where(:feature_flag_enabled, :user_can_read_product_analytics, :expected_result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        stub_feature_flags(product_analytics_usage_quota: feature_flag_enabled)
        allow(helper).to receive(:can?).with(current_user, :read_product_analytics, group).and_return(user_can_read_product_analytics)
      end

      it 'returns the expected result' do
        expect(helper.show_product_analytics_usage_quota_tab?(group)).to eq(expected_result)
      end
    end
  end

  describe '#saml_sso_settings_generate_helper_text' do
    let(:text) { 'some text' }
    let(:result) { "<span class=\"js-helper-text gl-clearfix\">#{text}</span>" }

    specify { expect(helper.saml_sso_settings_generate_helper_text(display_none: false, text: text)).to eq result }
    specify { expect(helper.saml_sso_settings_generate_helper_text(display_none: true, text: text)).to include('gl-display-none') }
  end

  describe '#group_transfer_app_data' do
    it 'returns expected hash' do
      expect(helper.group_transfer_app_data(group)).to eq({
        full_path: group.full_path
      })
    end
  end

  describe '#subgroup_creation_data' do
    subject { helper.subgroup_creation_data(group) }

    context 'when self-managed' do
      it { is_expected.to include(is_saas: 'false') }
    end

    context 'when on .com', :saas do
      it { is_expected.to include(is_saas: 'true') }
    end
  end

  describe '#can_admin_service_accounts?', feature_category: :user_management do
    it 'returns true when current_user can admin members' do
      stub_licensed_features(service_accounts: true)

      expect(helper.can_admin_service_accounts?(group)).to be(true)
    end

    it 'returns false when current_user can not admin members' do
      expect(helper.can_admin_service_accounts?(group)).to be(false)
    end
  end

  describe '#enabled_git_access_protocol_options_for_group' do
    let_it_be(:group) { create(:group) }

    subject { helper.enabled_git_access_protocol_options_for_group(group) }

    before do
      allow(::Gitlab::CurrentSettings).to receive(:enabled_git_access_protocol).and_return(instance_setting)
    end

    context "instance setting is nil" do
      let(:instance_setting) { nil }

      it 'returns all settings' do
        is_expected.to contain_exactly(
          [_("Both SSH and HTTP(S)"), "all"],
          [_("Only SSH"), "ssh"],
          [_("Only HTTP(S)"), "http"]
        )
      end
    end

    context 'when ssh_certificates licensed feature is available' do
      before do
        stub_licensed_features(ssh_certificates: true)
      end

      context "instance setting is nil" do
        let(:instance_setting) { nil }

        it 'returns all settings' do
          is_expected.to contain_exactly(
            [_("Both SSH and HTTP(S)"), "all"],
            [_("Only SSH"), "ssh"],
            [_("Only HTTP(S)"), "http"],
            [_("Only SSH Certificates"), "ssh_certificates"]
          )
        end

        context 'when enforce_ssh_certificates is disabled' do
          before do
            stub_feature_flags(enforce_ssh_certificates: false)
          end

          it 'does not return SSH Certificates label' do
            is_expected.to contain_exactly(
              [_("Both SSH and HTTP(S)"), "all"],
              [_("Only SSH"), "ssh"],
              [_("Only HTTP(S)"), "http"]
            )
          end
        end
      end

      context 'when instance setting is ssh_certificates' do
        let(:instance_setting) { 'ssh_certificates' }

        it 'returns SSH Certificates label' do
          is_expected.to contain_exactly([_("Only SSH Certificates"), "ssh_certificates"])
        end
      end

      context "instance setting is ssh" do
        let(:instance_setting) { "ssh" }

        it { is_expected.to contain_exactly([_("Only SSH"), "ssh"]) }
      end

      context "instance setting is http" do
        let(:instance_setting) { "http" }

        it { is_expected.to contain_exactly([_("Only HTTP(S)"), "http"]) }
      end
    end
  end
end
