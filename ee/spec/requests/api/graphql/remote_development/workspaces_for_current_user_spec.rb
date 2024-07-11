# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared'

RSpec.describe 'Query.currentUser.workspaces', feature_category: :remote_development do
  include GraphqlHelpers

  include_context 'with other user'

  let_it_be(:workspace) { create(:workspace) }

  # create workspace owned by different user, to ensure it is not returned by the query
  let_it_be(:non_matching_workspace) { create(:workspace, user: other_user) }

  let(:args) { {} }
  let(:fields) do
    <<~QUERY
      nodes {
        #{all_graphql_fields_for('workspaces'.classify, max_depth: 2)}
      }
    QUERY
  end

  let(:query) { graphql_query_for('currentUser', args, query_graphql_field('workspaces', {}, fields)) }

  subject { graphql_data.dig('currentUser', 'workspaces', 'nodes') }

  it_behaves_like 'multiple workspaces query'
end
