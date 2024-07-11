# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::CreatorService, feature_category: :groups_and_projects do
  describe '.add_member' do
    let_it_be(:user) { create(:user) }

    context 'for onboarding concerns', :saas do
      let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
        create(:group_member, source: group)
      end

      context 'when user qualifies for being in onboarding' do
        context 'when user has finished the welcome step' do
          before do
            user.update!(onboarding_in_progress: true, onboarding_step_url: '_url_')
          end

          it 'finishes onboarding' do
            expect do
              described_class.add_member(group, user, :owner)
            end.to change { user.reset.onboarding_in_progress }.from(true).to(false)
          end
        end

        context 'when user has not finished the welcome step' do
          before do
            user.update!(role: nil, onboarding_in_progress: true, onboarding_step_url: '_url_')
          end

          it 'does not finish onboarding' do
            expect do
              described_class.add_member(group, user, :owner)
            end.not_to change { user.reset.onboarding_in_progress }
          end
        end
      end

      context 'when user does not qualify for onboarding' do
        let(:check_namespace_plan) { false }

        context 'when user has finished the welcome step' do
          before do
            user.update!(onboarding_in_progress: true, onboarding_step_url: '_url_')
          end

          it 'does not finish onboarding' do
            expect do
              described_class.add_member(group, user, :owner)
            end.not_to change { user.reset.onboarding_in_progress }
          end
        end
      end
    end

    context 'when user is a security_policy_bot' do
      let_it_be(:user) { create(:user, :security_policy_bot) }
      let_it_be(:project) { create(:project) }

      subject { described_class.add_member(project, user, :guest) }

      it 'adds a member' do
        expect { subject }.to change { Member.count }.by(1)
      end

      context 'when the user is already a member of another project' do
        let_it_be(:other_project) { create(:project) }
        let_it_be(:membership) { create(:project_member, :guest, source: other_project, user: user) }

        it 'does not add a member' do
          expect { subject }.not_to change { Member.count }
        end

        it 'adds an error message to the member' do
          expect(subject.errors.messages).to include(
            base: ['security policy bot users cannot be added to other projects']
          )
        end
      end
    end

    context 'when assigning a member role' do
      let_it_be(:group) { create(:group) }
      let_it_be(:member_role) { create(:member_role, :guest, namespace: group) }

      subject(:add_member) do
        described_class.add_member(group, user, :guest, member_role_id: member_role.id)
      end

      context 'with custom_roles feature' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'with invitations_member_role_id feature flag enabled' do
          before do
            stub_feature_flags(invitations_member_role_id: true)
          end

          it 'adds a user to members with custom role assigned' do
            expect { add_member }.to change { group.members.count }.by(1)

            member = Member.last

            expect(member.member_role).to eq(member_role)
            expect(member.access_level).to eq(Member::GUEST)
          end
        end

        context 'with invitations_member_role_id feature flag disabled' do
          before do
            stub_feature_flags(invitations_member_role_id: false)
          end

          it 'adds a user to members without custom role assigned' do
            expect { add_member }.to change { group.members.count }.by(1)

            member = Member.last

            expect(member.member_role).to be_nil
            expect(member.access_level).to eq(Member::GUEST)
          end
        end
      end

      context 'without custom_roles feature' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'adds a user to members without custom role assigned' do
          expect { add_member }.to change { group.members.count }.by(1)

          member = Member.last

          expect(member.member_role).to be_nil
          expect(member.access_level).to eq(Member::GUEST)
        end
      end
    end
  end
end
