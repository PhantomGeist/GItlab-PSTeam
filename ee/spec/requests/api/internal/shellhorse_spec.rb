# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Shellhorse, feature_category: :source_code_management do
  include GitlabShellHelpers
  include APIInternalBaseHelpers
  include NamespaceStorageHelpers

  describe "POST /internal/shellhorse/git_audit_event", :clean_gitlab_redis_shared_state do
    let_it_be(:user, reload: true) { create(:user) }
    let_it_be(:group) { create(:group, :public) }
    let_it_be(:project, reload: true) { create(:project, :repository, :wiki_repo, namespace: group) }
    let(:gl_repository) { "project-#{project.id}" }
    let(:key) { create(:key, user: user) }

    before do
      create(:external_audit_event_destination, group: group)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    subject { post api('/internal/shellhorse/git_audit_event'), params: valid_params, headers: header }

    shared_context 'with git audit event env' do |shell_or_horse, protocol|
      include_context 'workhorse headers'

      let(:header) { shell_or_horse == 'shell' ? gitlab_shell_internal_api_request_header : workhorse_headers }
      let(:protocol) { protocol }
      let(:valid_params) do
        {
          protocol: protocol,
          action: action,
          username: key.user.username,
          gl_repository: gl_repository,
          packfile_stats: packfile_stats
        }
      end

      let(:expected_msg) { { protocol: protocol, action: action, verb: verb } }
    end

    shared_examples 'logs single streaming audit event' do
      using RSpec::Parameterized::TableSyntax

      where(:action, :verb, :packfile_stats) do
        'git-receive-pack' | 'push'     | {}
        'git-upload-pack'  | 'clone'    | { wants: 2 }           #=> { wants: 2, haves: 0 }
        'git-upload-pack'  | 'pull'     | { wants: 2, haves: 2 } #=> { wants: 2, haves: 2 }
        'git-upload-pack'  | 'pull'     | { haves: 2 }           #=> { wants: 0, haves: 2 }
        'git-upload-pack'  | 'pull'     | {}                     #=> { wants: 0, haves: 0 }
      end

      before do
        valid_params.merge!({ changes: '_any' }) if verb == 'push'
      end

      with_them do
        it "logs git #{params[:verb]} streaming audit event for #{params[:action]}" do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(
            name: 'repository_git_operation',
            stream_only: true,
            author: user,
            scope: project,
            target: project,
            message: expected_msg
          )).once

          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response["status"]).to be_truthy
          expect(json_response["message"]).to eq(expected_msg.stringify_keys)
        end

        context 'when log_git_streaming_audit_events is disable' do
          before do
            stub_feature_flags(log_git_streaming_audit_events: false)
          end

          it "does not log git #{params[:verb]} streaming audit event for #{params[:action]}" do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

            subject

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end

    shared_examples 'logs streaming audit events' do |shell_or_horse, protocol|
      include_context 'with git audit event env', shell_or_horse, protocol

      before do
        project.add_developer(user)
      end

      context "when #{protocol} protocol from #{shell_or_horse} request" do
        it_behaves_like 'logs single streaming audit event'
      end
    end

    shared_examples 'break response in several invalid cases' do |shell_or_horse, protocol|
      include_context 'with git audit event env', shell_or_horse, protocol

      let(:action) { 'git-upload-pack' }
      let(:packfile_stats) { { wants: 0, haves: 0 } }
      let(:verb) { 'clone' }

      context "when #{protocol} protocol from #{shell_or_horse} request" do
        context "with invalid action" do
          let(:action) { 'git_invalid_action' }

          it 'response with not found' do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['success']).to be_falsey
            expect(json_response['message']).to eq('No valid action specified')
          end
        end

        context "when user does not exist" do
          before do
            valid_params.merge!({ username: 'none_user' })
          end

          it 'response with not found' do
            subject

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response["status"]).to be_falsey
            expect(json_response['message']).to include("you don't have permission to view it")
          end
        end

        context "when project does not exist" do
          before do
            valid_params.merge!({ gl_repository: "project-#{non_existing_record_id}" })
          end

          it 'response with not found' do
            subject

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response["status"]).to be_falsey
            expect(json_response['message']).to include("namespace you were looking for could not be found")
          end
        end

        context 'when request times out' do
          it 'responds with a timeout' do
            expect_next_instance_of(Gitlab::GitAccess) do |access|
              expect(access).to receive(:check).and_raise(Gitlab::GitAccess::TimeoutError, "Timeout")
            end
            subject

            expect(response).to have_gitlab_http_status(:service_unavailable)
            expect(json_response['status']).to be_falsey
            expect(json_response['message']).to eq("Timeout")
          end
        end

        context "when access denied" do
          before do
            project.add_guest(user)
          end

          context "when git upload pack" do
            it 'response with none access' do
              subject

              expect(response).to have_gitlab_http_status(:unauthorized)
              expect(json_response["status"]).to be_falsey
            end
          end

          context "when git receive pack" do
            let(:action) { 'git-receive-pack' }
            let(:verb) { 'push' }

            before do
              valid_params.merge!({ changes: '_any' })
            end

            it 'responsed with none access' do
              subject

              expect(response).to have_gitlab_http_status(:unauthorized)
              expect(json_response["status"]).to be_falsey
            end
          end
        end

        context 'when result is not ::Gitlab::GitAccessResult::Success' do
          it 'responds with 500' do
            allow_next_instance_of(Gitlab::GitAccess) do |access|
              allow(access).to receive(:check).and_return(nil)
            end

            subject

            expect(response).to have_gitlab_http_status(:internal_server_error)
            expect(json_response['status']).to be_falsey
            expect(json_response['message']).to eq(::API::Helpers::InternalHelpers::UNKNOWN_CHECK_RESULT_ERROR)
          end
        end
      end
    end

    { shell: 'Gitlab Shell', horse: 'Gitlab Workhorse' }.each do |key, val|
      context "when #{val} requests" do
        %w[ssh http].freeze.each do |protocol|
          context "with #{protocol} protocol" do
            it_behaves_like 'logs streaming audit events', key, protocol
            it_behaves_like 'break response in several invalid cases', key, protocol
          end
        end
      end
    end
  end
end
