# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared'

RSpec.describe 'Query.workspaces(ids: [RemoteDevelopmentWorkspaceID!])', feature_category: :remote_development do
  include GraphqlHelpers

  let_it_be(:workspace) { create(:workspace) }

  # create workspace with different ID but still owned by user, to ensure it is not returned by the query
  let_it_be(:non_matching_workspace) { create(:workspace, user: workspace.user) }

  let(:ids) { [workspace.to_global_id.to_s] }
  let(:args) { { ids: ids } }
  let(:fields) do
    <<~QUERY
      nodes {
        #{all_graphql_fields_for('workspaces'.classify, max_depth: 2)}
      }
    QUERY
  end

  let(:query) { graphql_query_for('workspaces', args, fields) }

  subject { graphql_data.dig('workspaces', 'nodes') }

  it_behaves_like 'multiple workspaces query'
end
