# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnvironmentsHelper do
  let_it_be_with_refind(:environment) { create(:environment) }
  let_it_be_with_refind(:deployment) { create(:deployment, :blocked, project: project, environment: environment) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { environment.project }

  describe '#can_approve_deployment?' do
    let_it_be(:protected_environment) do
      create(:protected_environment, name: environment.name, project: project, authorize_user_to_deploy: user)
    end

    subject { helper.can_approve_deployment?(deployment) }

    before do
      stub_licensed_features(protected_environments: true)

      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'when environment has a unified approval setting' do
      context 'user has access' do
        before do
          project.add_developer(user)
        end

        context 'with required approvals count = 0' do
          it 'returns false' do
            expect(subject).to be(false)
          end
        end

        context 'with required approvals count > 0' do
          before do
            protected_environment.update!(required_approval_count: 2)
          end

          it 'returns true' do
            expect(subject).to be(true)
          end
        end
      end

      context 'user does not have access' do
        before do
          project.add_reporter(user)
        end

        it 'returns false' do
          expect(subject).to be(false)
        end
      end
    end

    context 'when environment has multiple approval rules' do
      let_it_be(:qa_group) { create(:group, name: 'QA') }
      let_it_be(:security_group) { create(:group, name: 'Security') }

      before do
        create(:protected_environment_approval_rule,
          group_id: qa_group.id,
          protected_environment: protected_environment)

        create(:protected_environment_approval_rule,
          group_id: security_group.id,
          protected_environment: protected_environment)
      end

      context 'user has access' do
        before do
          qa_group.add_developer(user)
          project.add_developer(user)
        end

        it 'returns true' do
          expect(subject).to be(true)
        end
      end

      context 'user does not have access' do
        context 'with no matching approval rules' do
          before do
            project.add_reporter(user)
          end

          it 'returns false' do
            expect(subject).to be(false)
          end
        end

        context 'when cannot read deployment' do
          before do
            qa_group.add_developer(user)
            project.add_guest(user)
          end

          it 'returns false' do
            expect(subject).to be(false)
          end
        end
      end
    end
  end
end
