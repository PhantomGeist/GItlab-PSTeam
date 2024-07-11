# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::SidebarsHelper, feature_category: :navigation do
  using RSpec::Parameterized::TableSyntax
  include Devise::Test::ControllerHelpers

  describe '#super_sidebar_context' do
    let_it_be(:user) { build(:user) }
    let_it_be(:panel) { {} }
    let_it_be(:panel_type) { 'project' }
    let(:current_user_mode) { Gitlab::Auth::CurrentUserMode.new(user) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(user.namespace).to receive(:actual_plan_name).and_return(::Plan::ULTIMATE)
      allow(helper).to receive(:current_user_menu?).and_return(true)
      allow(helper).to receive(:can?).and_return(true)
      allow(helper).to receive(:show_buy_pipeline_with_subtext?).and_return(true)
      allow(helper).to receive(:current_user_mode).and_return(current_user_mode)
      allow(panel).to receive(:super_sidebar_menu_items).and_return(nil)
      allow(panel).to receive(:super_sidebar_context_header).and_return(nil)
      allow(user).to receive(:assigned_open_issues_count).and_return(1)
      allow(user).to receive(:assigned_open_merge_requests_count).and_return(4)
      allow(user).to receive(:review_requested_open_merge_requests_count).and_return(0)
      allow(user).to receive(:todos_pending_count).and_return(3)
      allow(user).to receive(:total_merge_requests_count).and_return(4)
    end

    # Tests for logged-out sidebar context,
    # because EE/CE should have the same attributes for logged-out users
    it_behaves_like 'logged-out super-sidebar context'

    shared_examples 'pipeline minutes attributes' do
      it 'returns sidebar values from user', :use_clean_rails_memory_store_caching do
        expect(subject).to have_key(:pipeline_minutes)
        expect(subject[:pipeline_minutes]).to include({
          show_buy_pipeline_minutes: true,
          show_notification_dot: false,
          show_with_subtext: true,
          tracking_attrs: {
            'track-action': 'click_buy_ci_minutes',
            'track-label': ::Plan::DEFAULT,
            'track-property': 'user_dropdown'
          },
          notification_dot_attrs: {
            'data-track-action': 'render',
            'data-track-label': 'show_buy_ci_minutes_notification',
            'data-track-property': ::Plan::ULTIMATE
          },
          callout_attrs: {
            feature_id: ::Ci::RunnersHelper::BUY_PIPELINE_MINUTES_NOTIFICATION_DOT,
            dismiss_endpoint: '/-/users/callouts'
          }
        })
      end
    end

    shared_examples 'trial status widget data' do
      describe 'trial status on .com', :saas do
        let_it_be(:root_group) { namespace.root_ancestor }
        let_it_be(:gitlab_subscription) { build(:gitlab_subscription, :active_trial, :free, namespace: root_group) }

        describe 'does not return trial status widget data' do
          where(:description, :should_check_namespace_plan, :show_trial_status_widget?, :can_admin) do
            'when instance does not check namespace plan' | false | true | true
            'when namespace does not qualify for widget' | true | false | true
            'when user cannot admin namespace' | true | true | false
          end

          with_them do
            before do
              allow(helper).to receive(:can?).with(user, :admin_namespace, root_group).and_return(can_admin)
              stub_ee_application_setting(should_check_namespace_plan: should_check_namespace_plan)
              allow(helper).to receive(:show_trial_status_widget?).and_return(show_trial_status_widget?)
            end

            it { is_expected.not_to include(:trial_status_widget_data_attrs) }
            it { is_expected.not_to include(:trial_status_popover_data_attrs) }
          end
        end

        context 'when a namespace is qualified for trial status widget' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_namespace, root_group).and_return(true)
            stub_ee_application_setting(should_check_namespace_plan: true)
            allow(helper).to receive(:show_trial_status_widget?).and_return(true)
          end

          it 'returns trial status widget data' do
            expect(subject[:trial_status_widget_data_attrs]).to match({
              container_id: "trial-status-sidebar-widget",
              nav_icon_image_path: match_asset_path("/assets/illustrations/golden_tanuki.svg"),
              percentage_complete: 50.0,
              plan_name: nil,
              plans_href: group_billings_path(root_group),
              trial_days_used: 15,
              trial_duration: 30
            })
            expect(subject[:trial_status_popover_data_attrs]).to eq({
              company_name: "",
              container_id: "trial-status-sidebar-widget",
              create_hand_raise_lead_path: "/-/subscriptions/hand_raise_leads",
              track_action: 'click_button',
              track_label: 'trial_status_popover_hand_raise_lead_form',
              days_remaining: 15,
              first_name: user.first_name,
              glm_content: "trial-status-show-group",
              product_interaction: 'Hand Raise PQL',
              last_name: user.last_name,
              namespace_id: nil,
              plan_name: nil,
              plans_href: group_billings_path(root_group),
              target_id: "trial-status-sidebar-widget",
              trial_end_date: root_group.trial_ends_on,
              user_name: user.username
            })
          end
        end
      end
    end

    context 'with global concerns' do
      subject do
        helper.super_sidebar_context(user, group: nil, project: nil, panel: panel, panel_type: nil)
      end

      it 'returns sidebar values from user', :use_clean_rails_memory_store_caching do
        trial = {
          has_start_trial: false,
          url: new_trial_path(glm_source: 'gitlab.com', glm_content: 'top-right-dropdown')
        }

        expect(subject).to include(trial: trial)
      end
    end

    context 'when in project scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(true)
      end

      let_it_be(:project) { build(:project) }
      let_it_be(:namespace) { project }
      let_it_be(:group) { nil }

      let(:subject) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      include_examples 'pipeline minutes attributes'
      include_examples 'trial status widget data'

      it 'returns correct usage quotes path', :use_clean_rails_memory_store_caching do
        expect(subject[:pipeline_minutes]).to include({
          buy_pipeline_minutes_path: "/-/profile/usage_quotas"
        })
      end
    end

    context 'when in group scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(true)
      end

      let_it_be(:group) { build(:group) }
      let_it_be(:namespace) { group }
      let_it_be(:project) { nil }

      let(:subject) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      include_examples 'pipeline minutes attributes'
      include_examples 'trial status widget data'

      it 'returns correct usage quotes path', :use_clean_rails_memory_store_caching do
        expect(subject[:pipeline_minutes]).to include({
          buy_pipeline_minutes_path: "/groups/#{group.path}/-/usage_quotas"
        })
      end
    end

    context 'when neither in a group nor in a project scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(false)
      end

      let_it_be(:project) { nil }
      let_it_be(:group) { nil }

      let(:subject) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      it 'does not have pipeline minutes attributes' do
        expect(subject).not_to have_key('pipeline_minutes')
      end
    end
  end
end
