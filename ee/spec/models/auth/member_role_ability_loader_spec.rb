# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Auth::MemberRoleAbilityLoader, feature_category: :system_access do
  describe '#has_ability?', :request_store do
    let_it_be(:project) { create(:project, :in_group) }
    let_it_be(:group) { project.group }
    let_it_be(:user) { create(:user) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when user is a deploy token or other non-user entity' do
      let_it_be(:user) { create(:project_deploy_token) }

      it 'returns false' do
        expect(described_class.new(
          user: user,
          resource: group,
          ability: :read_vulnerability
        ).has_ability?).to eq false
      end
    end

    context 'when user not a member' do
      it 'returns false' do
        expect(described_class.new(
          user: user,
          resource: project,
          ability: :read_code
        ).has_ability?).to eq false
      end
    end

    context 'when custom role is for a group' do
      before_all do
        group_member = create(:group_member, :guest, user: user, source: group)
        create(
          :member_role,
          :guest,
          admin_vulnerability: false,
          read_code: false,
          read_vulnerability: true,
          members: [group_member],
          namespace: group
        )
      end

      context 'when custom role present for group membership' do
        it 'returns custom role information on the group' do
          expect(described_class.new(
            user: user,
            resource: group,
            ability: :read_vulnerability
          ).has_ability?).to be true

          expect(described_class.new(
            user: user,
            resource: group,
            ability: :admin_vulnerability
          ).has_ability?).to be false

          expect(described_class.new(
            user: user,
            resource: group,
            ability: :read_code
          ).has_ability?).to be false
        end

        it 'returns inherited custom role information on the projects within the group' do
          expect(described_class.new(
            user: user,
            resource: project,
            ability: :read_vulnerability
          ).has_ability?).to be true

          expect(described_class.new(
            user: user,
            resource: project,
            ability: :admin_vulnerability
          ).has_ability?).to be false

          expect(described_class.new(
            user: user,
            resource: project,
            ability: :read_code
          ).has_ability?).to be false
        end
      end
    end

    context 'when custom role is for a project' do
      before_all do
        project_member = create(:project_member, :guest, user: user, source: project)
        create(
          :member_role,
          :guest,
          admin_vulnerability: false,
          read_code: true,
          read_vulnerability: false,
          members: [project_member],
          namespace: project.group
        )
      end

      context 'when read_code present in preloaded custom roles' do
        it 'returns custom role information on the the project' do
          expect(described_class.new(
            user: user,
            resource: project,
            ability: :read_vulnerability
          ).has_ability?).to be false

          expect(described_class.new(
            user: user,
            resource: project,
            ability: :admin_vulnerability
          ).has_ability?).to be false

          expect(described_class.new(
            user: user,
            resource: project,
            ability: :read_code
          ).has_ability?).to be true
        end

        it "returns false for all custom permissions on the project's parent group" do
          expect(described_class.new(
            user: user,
            resource: group,
            ability: :read_vulnerability
          ).has_ability?).to be false

          expect(described_class.new(
            user: user,
            resource: group,
            ability: :admin_vulnerability
          ).has_ability?).to be false

          expect(described_class.new(
            user: user,
            resource: group,
            ability: :read_code
          ).has_ability?).to be false
        end
      end

      context 'when called with a ProjectPresenter' do
        it 'returns the correct preloaded custom ability' do
          expect(described_class.new(
            user: user,
            resource: ProjectPresenter.new(project),
            ability: :read_vulnerability
          ).has_ability?).to be false

          expect(described_class.new(
            user: user,
            resource: ProjectPresenter.new(project),
            ability: :admin_vulnerability
          ).has_ability?).to be false

          expect(described_class.new(
            user: user,
            resource: ProjectPresenter.new(project),
            ability: :read_code
          ).has_ability?).to be true
        end
      end
    end
  end
end
