# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MemberRolePermission'], feature_category: :system_access do
  specify { expect(described_class.graphql_name).to eq('MemberRolePermission') }

  it 'exposes all the existing custom permissions' do
    expect(described_class.values.keys)
      .to match_array(::MemberRole::ALL_CUSTOMIZABLE_PERMISSIONS.keys.map(&:to_s).map(&:upcase))
  end
end
