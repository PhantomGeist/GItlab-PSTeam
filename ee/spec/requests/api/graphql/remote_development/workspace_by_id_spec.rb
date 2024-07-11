# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared'

RSpec.describe 'Query.workspace(id: RemoteDevelopmentWorkspaceID!)', feature_category: :remote_development do
  include GraphqlHelpers

  let_it_be(:workspace) { create(:workspace) }
  let(:id) { workspace.to_global_id.to_s }
  let(:args) { { id: id } }
  let(:fields) do
    <<~QUERY
      #{all_graphql_fields_for('workspace'.classify, max_depth: 2)}
    QUERY
  end

  let(:query) { graphql_query_for('workspace', args, fields) }

  subject { graphql_data['workspace'] }

  it_behaves_like 'single workspace query'
end
