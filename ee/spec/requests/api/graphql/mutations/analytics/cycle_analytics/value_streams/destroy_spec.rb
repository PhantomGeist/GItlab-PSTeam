# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a value stream', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:value_stream) { create(:cycle_analytics_value_stream) }

  let(:mutation_name) { :value_stream_destroy }

  let(:mutation) do
    graphql_mutation(
      mutation_name,
      id: value_stream.to_global_id
    )
  end

  before do
    stub_licensed_features(cycle_analytics_for_groups: true)
  end

  context 'when user has permissions to delete value streams' do
    before_all do
      value_stream.namespace.add_reporter(current_user)
    end

    it 'deletes value stream' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { ::Analytics::CycleAnalytics::ValueStream.count }.by(-1)
    end

    context 'when an error happens' do
      before do
        allow_next_found_instance_of(::Analytics::CycleAnalytics::ValueStream) do |instance|
          allow(instance).to receive(:destroy).and_return(false)
        end
      end

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(graphql_mutation_response(:value_stream_destroy)['errors'])
          .to include('Error deleting the value stream')
      end
    end
  end

  context 'when the user does not have permission to create a value stream' do
    it_behaves_like 'a mutation that returns a top-level access error'
  end
end
