# frozen_string_literal: true

module QA
  RSpec.describe 'Govern', :runner, product_group: :threat_insights do
    describe 'MR security widget' do
      let(:secret_detection_report) { "gl-secret-detection-report.json" }
      let(:secret_detection_report_mr) { "gl-secret-detection-report-mr.json" }

      let!(:project) do
        create(:project,
          name: 'project-with-vulnerabilities',
          description: 'To test dismissed vulnerabilities in MR widget')
      end

      let!(:artefacts_directory) do
        Pathname.new(EE::Runtime::Path.fixture('dismissed_security_findings_mr_widget'))
      end

      let!(:runner) do
        create(:project_runner, project: project, name: "runner-for-#{project.name}", tags: ['secure_report'])
      end

      let!(:repository) do
        build(:commit, project: project, commit_message: 'Add report files') do |commit|
          commit.add_directory(artefacts_directory)
        end.fabricate_via_api!
      end

      let!(:ci_yaml_commit) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          ci_file(secret_detection_report).merge(action: 'create')
        ])
      end

      let(:source_mr_repository) do
        create(:commit,
          project: project,
          branch: 'test-dismissed-vulnerabilities',
          start_branch: project.default_branch,
          commit_message: 'new secret detection findings report in yml file',
          actions: [ci_file(secret_detection_report_mr).merge(action: 'update')])
      end

      let(:merge_request) do
        create(:merge_request,
          project: project,
          source: source_mr_repository,
          source_branch: 'test-dismissed-vulnerabilities',
          target_branch: project.default_branch)
      end

      before do
        Flow::Login.sign_in
        project.visit!
      end

      after do
        runner.remove_via_api!
      end

      it 'checks that dismissed vulnerabilities do not show up',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/415291' do
        Page::Project::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Project::Secure::SecurityDashboard.perform do |security_dashboard|
          security_dashboard.wait_for_vuln_report_to_load
          security_dashboard.select_all_vulnerabilities
          security_dashboard.change_state('dismissed', 'not_applicable')
        end

        merge_request.project.visit! # Hoping that the merge_request object will be fully fabricated before visit!
        wait_for_mr_pipeline_success
        merge_request.visit!

        Page::MergeRequest::Show.perform do |merge_request|
          expect(merge_request).to have_vulnerability_report
          merge_request.expand_vulnerability_report
          expect(merge_request).to have_vulnerability_count(2)
          expect(merge_request).to have_secret_detection_vulnerability_count_of(2)
        end
      end

      private

      def wait_for_mr_pipeline_success
        Support::Retrier.retry_until(max_duration: 10, message: "Waiting for MR pipeline to complete",
          sleep_interval: 2) do
          pipeline = project.pipelines.find { |item| item[:source] == "merge_request_event" }
          pipeline[:status] == "success" if pipeline
        end
      end

      def ci_file(report_name)
        {
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            workflow:
              rules:
                - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
                - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

            include:
              template: Jobs/Secret-Detection.latest.gitlab-ci.yml

            secret_detection:
              tags: [secure_report]
              script:
                - echo "Skipped"
              artifacts:
                reports:
                  secret_detection: #{report_name}
          YAML
        }
      end
    end
  end
end
