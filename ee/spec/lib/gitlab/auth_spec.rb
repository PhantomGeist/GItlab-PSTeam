# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth, :use_clean_rails_memory_store_caching, feature_category: :system_access do
  let_it_be(:project) { create(:project) }

  let(:auth_failure) { { actor: nil, project: nil, type: nil, authentication_abilities: nil } }
  let(:gl_auth) { described_class }

  describe '.find_for_git_client' do
    let(:request) { instance_double(ActionDispatch::Request, ip: 'ip') }

    context 'when using personal access token as password' do
      shared_examples 'successfully authenticates' do
        it 'successfully authenticates' do
          expect(
            gl_auth.find_for_git_client(
              personal_access_token.user.username,
              personal_access_token.token,
              project: project,
              request: request
            )
          ).to have_attributes(
            actor: personal_access_token.user,
            project: nil,
            type: :personal_access_token,
            authentication_abilities: described_class.full_authentication_abilities
          )
        end
      end

      shared_examples 'fails to authenticate' do
        it 'fails to authenticate' do
          expect(
            gl_auth.find_for_git_client(
              personal_access_token.user.username,
              personal_access_token.token,
              project: project,
              request: request
            )
          ).to have_attributes(auth_failure)
        end
      end

      context 'when personal access tokens are disabled' do
        before do
          stub_licensed_features(disable_personal_access_tokens: true)
          stub_application_setting(disable_personal_access_tokens: true)
        end

        context 'when using personal access token' do
          let_it_be(:personal_access_token) { create(:personal_access_token, scopes: ['api']) }

          context 'when project is nil' do
            let(:project) { nil }

            include_examples 'fails to authenticate'
          end
        end

        context 'when using impersonation token' do
          let_it_be(:personal_access_token) { create(:personal_access_token, :impersonation, scopes: ['api']) }

          context 'when project is nil' do
            let(:project) { nil }

            include_examples 'fails to authenticate'
          end
        end

        context 'when using a resource access token' do
          let_it_be(:project_bot_user) { create(:user, :project_bot) }
          let_it_be(:personal_access_token) { create(:personal_access_token, user: project_bot_user) }

          context 'when the user is a member of the project' do
            before_all do
              project.add_maintainer(project_bot_user)
            end

            include_examples 'fails to authenticate'
          end
        end
      end

      context "when using a service account's personal access token" do
        let_it_be(:service_account) { create(:user, :service_account) }
        let_it_be(:personal_access_token) { create(:personal_access_token, user: service_account) }

        context 'when the service account is a member of the project' do
          before_all do
            project.add_maintainer(service_account)
          end

          include_examples 'successfully authenticates'
        end

        context 'when the service account is not a member of the project' do
          include_examples 'fails to authenticate'
        end

        context 'when project is nil' do
          let(:project) { nil }

          include_examples 'successfully authenticates'
        end
      end
    end

    context 'when using build token as password' do
      subject { gl_auth.find_for_git_client(username, build.token, project: project, request: request) }

      let(:username) { 'gitlab-ci-token' }

      context 'for running build' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }
        let(:build) { create(:ci_build, :running, project: project) }

        context 'when the build author is the service account' do
          let_it_be(:service_account) { create(:user, :service_account) }

          before do
            build.update!(user: service_account)
          end

          it 'recognises project level service_account access token' do
            project.add_maintainer(build.user)

            expect(subject).to have_attributes(
              actor: build.user,
              project: build.project,
              type: :build,
              authentication_abilities: described_class.build_authentication_abilities
            )
          end

          it 'recognises group level service_account access token' do
            group.add_maintainer(build.user)

            expect(subject).to have_attributes(
              actor: build.user,
              project: build.project,
              type: :build,
              authentication_abilities: described_class.build_authentication_abilities
            )
          end
        end
      end
    end

    describe 'available_scopes' do
      describe 'ai_features scope' do
        let(:third_party_ai_features_enabled) { false }
        let(:experiment_features_enabled) { false }
        let(:namespace_settings) do
          build_stubbed(:namespace_settings,
            third_party_ai_features_enabled: third_party_ai_features_enabled,
            experiment_features_enabled: experiment_features_enabled)
        end

        let(:namespace) { build_stubbed(:namespace, namespace_settings: namespace_settings) }
        let(:root_group) { build_stubbed(:group, namespace_settings: namespace_settings) }

        let(:resource) { nil }

        subject { described_class.available_scopes_for(resource) }

        context 'when resource is user' do
          let(:resource) { build_stubbed(:user) }

          context 'and user has a group with ai features' do
            it 'includes ai features' do
              expect(resource).to receive(:any_group_with_ai_available?).and_return(true)

              is_expected.to include(:ai_features)
            end
          end

          context 'without ai features' do
            it { is_expected.not_to include(:ai_features) }
          end
        end

        context 'when resource is project' do
          let(:resource) { build_stubbed(:project, namespace: root_group) }

          context 'with a namespace that has ai features' do
            let(:third_party_ai_features_enabled) { true }
            let(:experiment_features_enabled) { true }

            it { is_expected.to include(:ai_features) }
          end

          context 'without ai features' do
            it { is_expected.not_to include(:ai_features) }
          end
        end

        context 'when resource is group' do
          let(:resource) { build_stubbed(:group, parent: root_group) }

          context 'with ai features' do
            let(:third_party_ai_features_enabled) { true }
            let(:experiment_features_enabled) { true }

            it { is_expected.to include(:ai_features) }
          end

          context 'without ai features' do
            it { is_expected.not_to include(:ai_features) }
          end
        end
      end
    end
  end
end
