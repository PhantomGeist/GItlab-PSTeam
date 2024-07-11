# frozen_string_literal: true

module QA
  RSpec.describe 'Govern' do
    describe 'User with minimal access to group', :requires_admin, product_group: :authentication_and_authorization do
      let(:admin_api_client) { Runtime::API::Client.as_admin }
      let(:user_with_minimal_access) { create(:user, api_client: admin_api_client) }
      let(:user_api_client) { Runtime::API::Client.new(:gitlab, user: user_with_minimal_access) }
      let(:group) { create(:group, path: "group-for-minimal-access-#{SecureRandom.hex(8)}") }
      let!(:project) { create(:project, :with_readme, name: 'project-for-minimal-access', group: group) }

      before do
        group.sandbox.add_member(user_with_minimal_access, Resource::Members::AccessLevel::MINIMAL_ACCESS)
      end

      after do
        user_with_minimal_access&.remove_via_api!
        project&.remove_via_api!
        begin
          group&.remove_via_api!
        rescue Resource::ApiFabricator::ResourceNotDeletedError
          # It is ok if the group is already marked for deletion by another test
        end
      end

      it 'is not allowed to push code via the CLI',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347873' do
        expect do
          Resource::Repository::Push.fabricate! do |push|
            push.repository_http_uri = project.repository_http_location.uri
            push.file_name = 'test.txt'
            push.file_content = "# This is a test project named #{project.name}"
            push.commit_message = 'Add test.txt'
            push.branch_name = 'new_branch'
            push.user = user_with_minimal_access
          end
        end.to raise_error(QA::Support::Run::CommandError, /You are not allowed to push code to this project/)
      end

      it 'is not allowed to create a file via the API',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347874' do
        expect do
          create(:file,
            api_client: user_api_client,
            project: project,
            branch: 'new_branch')
        end.to raise_error(Resource::ApiFabricator::ResourceFabricationFailedError, /403 Forbidden/)
      end

      it 'is not allowed to commit via the API',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347652' do
        expect do
          Resource::Repository::Commit.fabricate_via_api! do |commit|
            commit.api_client = user_api_client
            commit.project = project
            commit.branch = 'new_branch'
            commit.start_branch = project.default_branch
            commit.commit_message = 'Add new file'
            commit.add_files([{ file_path: 'test.txt', content: 'new file' }])
          end
        end.to raise_error(Resource::ApiFabricator::ResourceFabricationFailedError,
          /403 Forbidden - You are not allowed to push into this branch/)
      end
    end
  end
end
