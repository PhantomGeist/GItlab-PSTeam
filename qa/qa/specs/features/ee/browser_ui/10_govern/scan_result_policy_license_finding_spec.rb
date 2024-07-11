# frozen_string_literal: true

module QA
  RSpec.describe 'Govern', :runner, only: { subdomain: %i[staging staging-canary] },
    product_group: :security_policies do
    describe 'Scan result policy' do
      let!(:project) do
        create(:project, :with_readme,
          name: 'project-with-fake-dependency-scan', description: 'Project to test license finding')
      end

      let!(:runner) do
        create(:project_runner, project: project, name: "runner-for-#{project.name}")
      end

      let!(:scan_result_policy_project) do
        QA::EE::Resource::SecurityScanPolicyProject.fabricate_via_api! do |commit|
          commit.full_path = project.full_path
        end
      end

      let!(:policy_project) do
        create(:project,
          group: project.group, add_name_uuid: false,
          name: Pathname.new(scan_result_policy_project.api_response[:full_path]).basename.to_s)
      end

      let(:scan_result_policy_name) { 'greyhound' }
      let(:policy_yaml_path) { "qa/ee/fixtures/scan_result_policy_yaml/scan_result_license_finding_policy.yml" }
      let(:dependency_scan_fixtures) { Pathname.new(EE::Runtime::Path.fixture('dependency_scanning_fixtures')) }

      let(:commit_branch) { "new_branch_#{SecureRandom.hex(8)}" }
      let!(:approver) do
        Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_1, Runtime::Env.gitlab_qa_password_1)
      end

      let(:scan_result_policy_commit) do
        QA::EE::Resource::ScanResultPolicyCommit.fabricate_via_api! do |commit|
          commit.policy_name = scan_result_policy_name
          commit.full_path = project.full_path
          commit.mode = :APPEND
          commit.policy_yaml = begin
            yaml_obj = YAML.load_file(policy_yaml_path)
            yaml_obj["actions"].first["user_approvers_ids"][0] = approver.id
            yaml_obj
          end
        end
      end

      let!(:ci_file) do
        {
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            dependency_scanning:
              stage: test
              script:
              - echo "Fake scan"
              artifacts:
                paths:
                  - "gl-sbom-*.cdx.json"
                reports:
                  cyclonedx: "gl-sbom-*.cdx.json"
                  dependency_scanning: gl-dependency-scanning-report.json
          YAML
        }
      end

      let!(:repository_commit) do
        build(:commit,
          project: project,
          start_branch: project.default_branch,
          branch: commit_branch,
          commit_message: 'Add dependency scan files and .gitlab-ci.yml') do |commit|
            commit.add_directory(dependency_scan_fixtures)
            commit.add_files([ci_file])
          end.fabricate_via_api!
      end

      before do
        project.add_member(approver)
        scan_result_policy_commit # fabricate scan result policy commit

        Flow::Login.sign_in
        project.visit!
      end

      after do
        runner.remove_via_api!
        project.remove_via_api!
      end

      it 'requires approval when license findings violate scan result policy',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/426073' do
        expect(scan_result_policy_commit.api_response).to have_key(:branch)
        expect(scan_result_policy_commit.api_response[:branch]).not_to be nil

        create_scan_result_policy
        # Create MR after creating the scan result policy
        merge_request = create_test_mr

        Flow::Pipeline.wait_for_latest_pipeline(status: 'passed')
        merge_request.visit!

        Page::MergeRequest::Show.perform do |mr|
          expect(mr).not_to be_mergeable
          expect(mr.approvals_required_from).to include(scan_result_policy_name)
        end
      end

      def create_test_mr
        Resource::MergeRequest.fabricate_via_api! do |merge_request|
          merge_request.no_preparation = true
          merge_request.project = project
          merge_request.target_new_branch = false
          merge_request.source_branch = commit_branch
        end
      end

      def create_scan_result_policy
        branch_name = scan_result_policy_commit.api_response[:branch]
        Resource::MergeRequest.fabricate_via_api! do |merge_request|
          merge_request.no_preparation = true
          merge_request.project = policy_project
          merge_request.target_new_branch = false
          merge_request.source_branch = branch_name
        end.merge_via_api!
      end
    end
  end
end
