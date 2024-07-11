# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a new value stream', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let(:mutation_name) { :value_stream_create }

  shared_examples 'a request to create value streams' do
    let(:mutation) do
      graphql_mutation(
        mutation_name,
        namespace_path: namespace.full_path,
        name: 'New value stream'
      )
    end

    before do
      stub_licensed_features(
        cycle_analytics_for_projects: true,
        cycle_analytics_for_groups: true
      )
    end

    context 'when user has permissions to create value streams' do
      before do
        namespace_object.add_reporter(current_user)
      end

      it 'creates a new value stream' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { ::Analytics::CycleAnalytics::ValueStream.count }.by(1)
      end

      it 'returns the created value stream' do
        post_graphql_mutation(mutation, current_user: current_user)

        value_stream = graphql_mutation_response(mutation_name)['valueStream']

        expect(value_stream).to be_present
        expect(value_stream['name']).to eq('New value stream')
      end
    end

    context 'when the user does not have permission to create a value stream' do
      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when Value Stream Analytics is not available for the namespace' do
      before do
        namespace_object.add_reporter(current_user)
        stub_licensed_features(cycle_analytics_for_projects: false)
        stub_licensed_features(cycle_analytics_for_groups: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end

  context 'when namespace is a project' do
    let_it_be(:namespace_object) { create(:project, group: create(:group)) }
    let(:namespace) { namespace_object.project_namespace }

    it_behaves_like 'a request to create value streams'
  end

  context 'when namespace is a group' do
    let_it_be(:namespace) { create(:group) }
    let(:namespace_object) { namespace }

    it_behaves_like 'a request to create value streams'
  end
end
