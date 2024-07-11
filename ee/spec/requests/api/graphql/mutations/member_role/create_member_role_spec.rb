# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'creating member role', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:name) { 'member role name' }
  let(:permissions) do
    values = {}
    MemberRole::ALL_CUSTOMIZABLE_PERMISSIONS.each do |permission, _options|
      values[permission] = true
    end

    values
  end

  let(:input) do
    {
      group_path: group.path,
      base_access_level: 'GUEST'
    }.merge(permissions)
  end

  let(:fields) do
    <<~FIELDS
      errors
      memberRole {
        id
        name
        description
        readVulnerability
        enabledPermissions
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(:member_role_create, input, fields) }

  subject(:create_member_role) { graphql_mutation_response(:member_role_create) }

  context 'without the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: false)
    end

    context 'with owner role' do
      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end

  # to make this spec passing add a new argument to the mutation
  # when implementing a new custom role permission
  context 'with the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'with maintainer role' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'with owner role' do
      before_all do
        group.add_owner(current_user)
      end

      context 'with valid arguments' do
        it 'returns success' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(graphql_errors).to be_nil
          expect(create_member_role['memberRole']['readVulnerability']).to eq(true)
          expect(create_member_role['memberRole']['enabledPermissions'])
            .to match_array(MemberRole::ALL_CUSTOMIZABLE_PERMISSIONS.keys.map(&:to_s).map(&:upcase))
        end

        it 'creates the member role' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { MemberRole.count }.by(1)

          member_role = MemberRole.last

          expect(member_role.read_vulnerability).to eq(true)
        end
      end

      context 'with missing arguments' do
        let(:input) { { group_path: group.path } }

        it_behaves_like 'an invalid argument to the mutation', argument_name: 'baseAccessLevel'
      end
    end
  end
end
