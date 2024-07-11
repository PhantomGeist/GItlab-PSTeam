# frozen_string_literal: true

require 'spec_helper'

# Creation is necessary due to relations and the need to check in the presenter
#
# rubocop:disable RSpec/FactoryBot/AvoidCreate
RSpec.describe MemberPresenter, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:member_root, reload: true) { create(:group_member, :reporter, group: root_group, user: user) }
  let_it_be(:member_subgroup, reload: true) { create(:group_member, :reporter, group: subgroup, user: user) }

  let(:presenter) { described_class.new(member_root, current_user: user) }

  describe '#human_access' do
    context 'when user has static role' do
      it 'returns human name for access level' do
        access_levels = {
          "Guest" => Gitlab::Access::GUEST,
          "Reporter" => Gitlab::Access::REPORTER,
          "Developer" => Gitlab::Access::DEVELOPER,
          "Maintainer" => Gitlab::Access::MAINTAINER,
          "Owner" => Gitlab::Access::OWNER
        }

        access_levels.each do |human_name, access_level|
          member_root.access_level = access_level
          expect(presenter.human_access).to eq human_name
        end
      end

      context 'when user has a custom role' do
        it 'returns custom roles' do
          member_role = create(:member_role, :guest, namespace: root_group)
          member_root.member_role = member_role
          member_root.access_level = Gitlab::Access::GUEST

          expect(presenter.human_access).to eq('Custom')
        end
      end
    end
  end

  describe '#valid_member_roles' do
    let_it_be(:member_role_guest) { create(:member_role, :guest, name: 'guest plus', namespace: root_group) }
    let_it_be(:member_role_reporter) { create(:member_role, :reporter, name: 'reporter plus', namespace: root_group) }

    context 'when custom_roles_in_members_page feature flag is enabled' do
      before do
        stub_feature_flags(custom_roles_in_members_page: true)
      end

      it 'returns only roles with higher base_access_level than user highest membership in the hierarchy' do
        expect(described_class.new(member_subgroup).valid_member_roles).to match_array(
          [
            { base_access_level: Gitlab::Access::REPORTER, member_role_id: member_role_reporter.id,
              name: 'reporter plus' }
          ]
        )
      end

      it 'returns all roles for the root group' do
        expect(described_class.new(member_root).valid_member_roles).to match_array(
          [
            { base_access_level: Gitlab::Access::REPORTER, member_role_id: member_role_reporter.id,
              name: 'reporter plus' },
            { base_access_level: Gitlab::Access::GUEST, member_role_id: member_role_guest.id,
              name: 'guest plus' }
          ]
        )
      end
    end

    context 'when custom_roles_in_members_page feature flag is disabled' do
      before do
        stub_feature_flags(custom_roles_in_members_page: false)
      end

      it 'returns an empty array' do
        expect(presenter.valid_member_roles).to be_empty
      end
    end
  end

  describe '#custom_permissions' do
    context 'when user has static role' do
      it 'returns an empty array' do
        expect(presenter.custom_permissions).to be_empty
      end
    end

    context 'when user has custom role' do
      it 'returns its abilities' do
        member_role = build_stubbed(
          :member_role, namespace: root_group, read_vulnerability: true, admin_merge_request: true
        )
        member_root.member_role = member_role

        expect(presenter.custom_permissions).to match_array(
          [{ key: :read_vulnerability, name: 'Read vulnerability' },
            { key: :admin_merge_request, name: 'Admin merge request' }]
        )
      end
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
