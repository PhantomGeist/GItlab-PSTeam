# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AnalyticsDashboardsHelper, feature_category: :product_analytics_data_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let_it_be(:project) { create(:project, group: group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:pointer) { create(:analytics_dashboards_pointer, :project_based, project: project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let_it_be(:group_pointer) { create(:analytics_dashboards_pointer, namespace: group, target_project: project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate

  let(:product_analytics_instrumentation_key) { '1234567890' }

  before do
    allow(helper).to receive(:current_user) { user }
    allow(helper).to receive(:image_path).and_return('illustrations/chart-empty-state.svg')
    allow(helper).to receive(:project_analytics_dashboards_path).with(project).and_return('/-/analytics/dashboards')

    stub_application_setting(product_analytics_data_collector_host: 'https://new-collector.example.com')
    stub_application_setting(project_collector_host: 'https://project-collector.example.com')
    stub_application_setting(cube_api_base_url: 'https://cube.example.com')
    stub_application_setting(cube_api_key: '0987654321')
  end

  describe '#analytics_dashboards_list_app_data' do
    context 'for project' do
      where(
        :product_analytics_enabled_setting,
        :feature_flag_enabled,
        :licensed_feature_enabled,
        :user_has_permission,
        :user_can_admin_project,
        :enabled
      ) do
        true  | true | true | true | true | true
        true  | true | true | true | false | true
        false | true | true | true | true | false
        true  | false | true | true | true | false
        true  | true | false | true | true | false
        true  | true | true | false | true | false
      end

      with_them do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: product_analytics_instrumentation_key)

          stub_application_setting(product_analytics_enabled: product_analytics_enabled_setting)

          stub_feature_flags(product_analytics_dashboards: feature_flag_enabled)
          stub_licensed_features(product_analytics: licensed_feature_enabled)

          allow(helper).to receive(:can?).with(user, :read_product_analytics, project).and_return(user_has_permission)
          allow(helper).to receive(:can?).with(user, :admin_project, project).and_return(user_can_admin_project)
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(project) }

        def expected_data(has_permission)
          {
            is_project: 'true',
            is_group: 'false',
            namespace_id: project.id,
            dashboard_project: {
              id: pointer.target_project.id,
              full_path: pointer.target_project.full_path,
              name: pointer.target_project.name
            }.to_json,
            can_configure_dashboards_project: user_can_admin_project.to_s,
            tracking_key: user_has_permission ? product_analytics_instrumentation_key : nil,
            collector_host: user_has_permission ? 'https://new-collector.example.com' : nil,
            chart_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
            dashboard_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
            analytics_settings_path: "/#{project.full_path}/-/settings/analytics#js-analytics-dashboards-settings",
            namespace_name: project.name,
            namespace_full_path: project.full_path,
            features: (enabled && has_permission ? [:product_analytics] : []).to_json,
            router_base: '/-/analytics/dashboards'
          }
        end

        context 'with snowplow' do
          before do
            stub_application_setting(product_analytics_configurator_connection_string: 'http://localhost:3000')
          end

          it 'returns the expected data' do
            expect(data).to eq(expected_data(true))
          end
        end
      end
    end

    context 'for sub group' do
      let_it_be(:sub_group) { create(:group, parent: group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate

      subject(:data) { helper.analytics_dashboards_list_app_data(sub_group) }

      def expected_data(collector_host)
        {
          is_project: 'false',
          is_group: 'true',
          namespace_id: sub_group.id,
          dashboard_project: nil,
          can_configure_dashboards_project: 'false',
          tracking_key: nil,
          collector_host: collector_host ? 'https://new-collector.example.com' : nil,
          chart_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
          dashboard_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
          analytics_settings_path: "/groups/#{sub_group.full_path}/-/edit#js-analytics-dashboards-settings",
          namespace_name: sub_group.name,
          namespace_full_path: sub_group.full_path,
          features: [].to_json,
          router_base: "/groups/#{sub_group.full_path}/-/analytics/dashboards"
        }
      end

      context 'when user does not have permission' do
        before do
          allow(helper).to receive(:can?).with(user, :read_product_analytics, sub_group).and_return(false)
        end

        it 'returns the expected data' do
          expect(data).to eq(expected_data(false))
        end
      end

      context 'when user has permission' do
        before do
          allow(helper).to receive(:can?).with(user, :read_product_analytics, sub_group).and_return(true)
        end

        it 'returns the expected data' do
          expect(data).to eq(expected_data(true))
        end
      end
    end

    context 'for group' do
      subject(:data) { helper.analytics_dashboards_list_app_data(group) }

      def expected_data(collector_host)
        {
          is_project: 'false',
          is_group: 'true',
          namespace_id: group.id,
          dashboard_project: {
            id: group_pointer.target_project.id,
            full_path: group_pointer.target_project.full_path,
            name: group_pointer.target_project.name
          }.to_json,
          can_configure_dashboards_project: 'false',
          tracking_key: nil,
          collector_host: collector_host ? 'https://new-collector.example.com' : nil,
          chart_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
          dashboard_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
          analytics_settings_path: "/groups/#{group.full_path}/-/edit#js-analytics-dashboards-settings",
          namespace_name: group.name,
          namespace_full_path: group.full_path,
          features: [].to_json,
          router_base: "/groups/#{group.full_path}/-/analytics/dashboards"
        }
      end

      context 'when user does not have permission' do
        before do
          allow(helper).to receive(:can?).with(user, :read_product_analytics, group).and_return(false)
        end

        it 'returns the expected data' do
          expect(data).to eq(expected_data(false))
        end
      end

      context 'when user has permission' do
        before do
          allow(helper).to receive(:can?).with(user, :read_product_analytics, group).and_return(true)
        end

        it 'returns the expected data' do
          expect(data).to eq(expected_data(true))
        end
      end
    end

    describe 'tracking_key' do
      where(
        :can_read_product_analytics,
        :project_instrumentation_key,
        :expected
      ) do
        false | nil | nil
        true | 'snowplow-key' | 'snowplow-key'
        true | nil | nil
      end

      with_them do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: project_instrumentation_key)

          stub_application_setting(product_analytics_configurator_connection_string: 'https://configurator.example.com')
          stub_application_setting(product_analytics_enabled: can_read_product_analytics)
          stub_feature_flags(product_analytics_dashboards: can_read_product_analytics)
          stub_licensed_features(product_analytics: can_read_product_analytics)
          allow(helper).to receive(:can?).with(user, :read_product_analytics,
            project).and_return(can_read_product_analytics)
          allow(helper).to receive(:can?).with(user, :admin_project, project).and_return(true)
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(project) }

        it 'returns the expected tracking_key' do
          expect(data[:tracking_key]).to eq(expected)
        end
      end
    end
  end

  describe '#analytics_project_settings_data' do
    where(
      :can_read_product_analytics,
      :project_instrumentation_key,
      :expected_tracking_key,
      :use_project_level
    ) do
      false | nil | nil | false
      true | 'snowplow-key' | 'snowplow-key' | false
      true | 'snowplow-key' | 'snowplow-key' | true
      true | nil | nil | false
    end

    with_them do
      before do
        project.project_setting.update!(
          product_analytics_instrumentation_key: project_instrumentation_key,
          product_analytics_data_collector_host:
            use_project_level ? 'https://project-collector.example.com' : nil
        )

        stub_application_setting(product_analytics_enabled: can_read_product_analytics)

        stub_feature_flags(product_analytics_dashboards: can_read_product_analytics)
        stub_licensed_features(product_analytics: can_read_product_analytics)

        allow(helper).to receive(:can?).with(user, :read_product_analytics,
          project).and_return(can_read_product_analytics)
      end

      subject(:data) { helper.analytics_project_settings_data(project) }

      it 'returns the expected data' do
        expected_collector = use_project_level ? 'https://project-collector.example.com' : 'https://new-collector.example.com'

        expect(data).to eq({
          tracking_key: can_read_product_analytics ? expected_tracking_key : nil,
          collector_host: can_read_product_analytics ? expected_collector : nil,
          dashboards_path: '/-/analytics/dashboards'
        })
      end
    end
  end
end
