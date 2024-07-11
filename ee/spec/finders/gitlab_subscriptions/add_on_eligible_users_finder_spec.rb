# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnEligibleUsersFinder, feature_category: :seat_cost_management do
  describe '#execute' do
    let_it_be_with_reload(:root_namespace) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_namespace) }

    let_it_be(:direct_project) { create(:project, namespace: root_namespace) }
    let_it_be(:sub_project) { create(:project, namespace: subgroup) }

    let_it_be(:banned_member) { create(:user) }
    let_it_be(:bot) { create(:user, :bot) }

    before_all do
      create(:namespace_ban, namespace: root_namespace, user: banned_member)
    end

    context 'when the namespace has no eligible users' do
      it 'returns an empty user collection' do
        expect(described_class.new(root_namespace, add_on_type: :code_suggestions).execute).to be_empty
      end
    end

    context 'when the namespace has eligible group members' do
      let_it_be(:direct_member) { create(:user) }
      let_it_be(:subgroup_member) { create(:user) }

      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_group_member) { create(:user) }

      before_all do
        create(:group_member, :invited, :developer, source: root_namespace)
        create(:group_member, :awaiting, :developer, source: root_namespace)
        create(:group_member, :minimal_access, source: root_namespace)
        create(:group_member, :access_request, :developer, source: root_namespace)
        create(:group_member, :developer, source: root_namespace, user: bot)

        root_namespace.add_owner(direct_member)
        subgroup.add_developer(subgroup_member)
        subgroup.add_developer(banned_member)

        other_group.add_owner(other_group_member)
      end

      it 'returns the users of members from all groups in the hierarchy' do
        expect(described_class.new(root_namespace, add_on_type: :code_suggestions).execute)
          .to match_array([direct_member, subgroup_member])
      end

      context 'when the namespace is not a root group' do
        it 'returns an empty user collection' do
          namespace = create(:group, parent: root_namespace)
          namespace.add_owner(create(:user))

          expect(described_class.new(namespace, add_on_type: :code_suggestions).execute).to be_empty
        end
      end

      context 'when supplied an unrecognised add on type' do
        it 'returns an empty user collection' do
          expect(described_class.new(root_namespace, add_on_type: :invalid_type).execute).to be_empty
        end
      end
    end

    context 'when the namespace has eligible users via group links' do
      let_it_be(:group_to_share_group_with) { create(:group) }
      let_it_be(:group_to_share_project_with) { create(:group) }

      let_it_be(:user_from_group_link) { create(:user) }
      let_it_be(:user_from_project_link) { create(:user) }

      before_all do
        create(:group_member, :minimal_access, source: group_to_share_group_with)
        create(:group_member, :developer, source: group_to_share_group_with, user: bot)
        create(:group_member, :awaiting, :developer, source: group_to_share_project_with)
        create(:group_member, :access_request, :developer, source: group_to_share_project_with)

        group_to_share_group_with.add_owner(user_from_group_link)
        group_to_share_project_with.add_developer(user_from_project_link)
        group_to_share_group_with.add_developer(banned_member)
        group_to_share_project_with.add_developer(banned_member)

        create(:group_group_link, shared_group: subgroup, shared_with_group: group_to_share_group_with)
        create(:project_group_link, project: sub_project, group: group_to_share_project_with)
      end

      it 'returns the users from the shared groups and projects' do
        expect(described_class.new(root_namespace, add_on_type: :code_suggestions).execute)
          .to match_array([user_from_group_link, user_from_project_link])
      end
    end

    context 'when the namespace has eligible project members' do
      let_it_be(:direct_project_member) { create(:user) }
      let_it_be(:sub_project_member) { create(:user) }
      let_it_be(:banned_project_member) { create(:user) }

      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_project_member) { create(:user) }

      before_all do
        create(:project_member, :invited, :developer, source: direct_project)
        create(:project_member, :awaiting, :developer, source: direct_project)
        create(:project_member, :access_request, :developer, source: direct_project)
        create(:project_member, :developer, source: direct_project, user: bot)

        direct_project.add_owner(direct_project_member)
        sub_project.add_developer(sub_project_member)

        sub_project.add_developer(banned_project_member)
        create(:namespace_ban, namespace: root_namespace, user: banned_project_member)

        other_project.add_owner(other_project_member)
      end

      it 'returns the users of all project members in the hierarchy' do
        expect(described_class.new(root_namespace, add_on_type: :code_suggestions).execute)
          .to match_array([direct_project_member, sub_project_member])
      end
    end

    context 'when supplied a valid search term' do
      let_it_be(:user_1) { create(:user, name: 'First User') }
      let_it_be(:user_2) { create(:user, name: 'Second User') }

      before_all do
        root_namespace.add_owner(user_1)
        subgroup.add_developer(user_2)
      end

      it 'filters the eligible users by search term' do
        finder = described_class.new(root_namespace, add_on_type: :code_suggestions, search_term: 'Second')

        expect(finder.execute).to match_array([user_2])
      end
    end
  end
end
