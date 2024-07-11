# frozen_string_literal: true

require "spec_helper"

RSpec.describe ProjectTeam, feature_category: :groups_and_projects do
  describe '#import_team' do
    let_it_be(:source_project) { create(:project) }
    let_it_be(:target_project) { create(:project) }
    let_it_be(:source_project_developer) { create(:user) { |user| source_project.add_developer(user) } }
    let_it_be(:current_user) { create(:user) { |user| target_project.add_maintainer(user) } }

    subject(:import) { target_project.team.import(source_project, current_user) }

    it 'does not cause N+1 queries when checking user types' do
      control_count = ActiveRecord::QueryRecorder.new { target_project.team.import(source_project, current_user) }

      create(:user, :security_policy_bot) { |user| source_project.add_guest(user) }

      expect { import }.not_to exceed_query_limit(control_count)
    end

    context 'when a source project member is a security policy bot' do
      let_it_be(:source_project_security_policy_bot) do
        create(:user, :security_policy_bot) { |user| source_project.add_guest(user) }
      end

      it 'does not import the security policy bot user' do
        import

        expect(target_project.members.find_by(user: source_project_security_policy_bot)).to eq(nil)
      end
    end
  end

  describe '#add_member' do
    let_it_be(:group) { create(:group) }
    let(:project) { create(:project, group: group) }
    let(:user) { create(:user) }

    context 'when group membership is locked' do
      before do
        group.update_attribute(:membership_lock, true)
      end

      it 'does not add the given user to the team' do
        project.team.add_member(user, :reporter)

        expect(project.members.map(&:user)).not_to include(user)
      end

      context 'when user is a project bot' do
        let_it_be(:project_bot) { create(:user, :project_bot) }

        it 'adds the project bot user to the team' do
          project.team.add_member(project_bot, :maintainer)

          expect(project.members.map(&:user)).to include(project_bot)
        end
      end

      context 'when user is a security policy bot' do
        let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

        it 'adds the project bot user to the team' do
          project.team.add_member(security_policy_bot, :maintainer)

          expect(project.members.map(&:user)).to include(security_policy_bot)
        end
      end
    end
  end
end
