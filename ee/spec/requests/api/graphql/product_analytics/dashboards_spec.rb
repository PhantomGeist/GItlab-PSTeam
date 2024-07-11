# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.resource(id).dashboards', feature_category: :product_analytics_data_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }

  let(:query) do
    fields = all_graphql_fields_for('CustomizableDashboard')

    graphql_query_for(
      resource_parent_type,
      { full_path: resource_parent.full_path },
      query_nodes(:customizable_dashboards, fields)
    )
  end

  shared_examples 'list dashboards as guest' do
    before do
      resource_parent.add_guest(user)
    end

    it 'returns no dashboards' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes)).to be_nil
    end
  end

  shared_examples 'list dashboards without analytics dashboards license' do
    before do
      stub_licensed_features(
        product_analytics: true,
        project_level_analytics_dashboard: false,
        group_level_analytics_dashboard: false
      )
    end

    it 'does not return the Value stream dashboard' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('slug'))
        .not_to include('value_stream_dashboard')
    end
  end

  context 'when resource parent is a project' do
    let_it_be_with_reload(:config_project) { create(:project, :with_product_analytics_dashboard) }
    let_it_be_with_reload(:resource_parent) { config_project }

    let(:resource_parent_type) { :project }

    before do
      stub_licensed_features(product_analytics: true, project_level_analytics_dashboard: true)
      resource_parent.project_setting.update!(product_analytics_instrumentation_key: "key")
      allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
          'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
        }))
      end

      resource_parent.reload
    end

    it_behaves_like 'list dashboards as guest'

    context 'when current user is a developer' do
      before do
        resource_parent.add_developer(user)
      end

      it 'returns all dashboards' do
        post_graphql(query, current_user: user)

        expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('title'))
          .to match_array(["Behavior", "Audience", "Value Stream Dashboard", "Dashboard Example 1"])
      end

      context 'when product analytics onboarding is incomplete' do
        before do
          resource_parent.project_setting.update!(product_analytics_instrumentation_key: nil)
        end

        it 'returns value stream and custom dashboards' do
          post_graphql(query, current_user: user)

          expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('title'))
            .to match_array(["Value Stream Dashboard", "Dashboard Example 1"])
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(product_analytics_dashboards: false)
        end

        it 'returns value stream and custom dashboards' do
          post_graphql(query, current_user: user)

          expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('title'))
            .to match_array(["Value Stream Dashboard", "Dashboard Example 1"])
        end
      end

      it_behaves_like 'list dashboards without analytics dashboards license'
    end
  end

  context 'when resource parent is a group' do
    let_it_be_with_reload(:resource_parent) { create(:group) }
    let_it_be_with_reload(:config_project) do
      create(:project, :with_product_analytics_dashboard, group: resource_parent)
    end

    let(:resource_parent_type) { :group }

    before do
      resource_parent.update!(analytics_dashboards_configuration_project: config_project)
      stub_licensed_features(product_analytics: true, group_level_analytics_dashboard: true)
    end

    it_behaves_like 'list dashboards as guest'

    context 'when current user is a developer' do
      before do
        resource_parent.add_developer(user)
      end

      it 'returns value stream and custom dashboards' do
        post_graphql(query, current_user: user)

        expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('title'))
          .to match_array(["Value Stream Dashboard", "Dashboard Example 1"])
      end

      it_behaves_like 'list dashboards without analytics dashboards license'
    end
  end
end
