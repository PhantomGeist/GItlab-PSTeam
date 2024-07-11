# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MemberRole'], feature_category: :system_access do
  let(:permissions) { MemberRole::ALL_CUSTOMIZABLE_PERMISSIONS.keys.map(&:to_s) }
  let(:fields) { %w[baseAccessLevel description id name enabledPermissions] + permissions }

  specify { expect(described_class.graphql_name).to eq('MemberRole') }

  # to make this spec passing add a new field to the type definition
  # when implementing a new custom role permission
  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class).to require_graphql_authorizations(:read_group_member) }
end
