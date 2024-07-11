# frozen_string_literal: true

module QA
  RSpec.describe 'Govern', :runner, :external_api_calls, product_group: :threat_insights do
    describe 'Security Reports' do
      let(:number_of_dependencies_dependency_scanning) { 9 }
      let(:dependency_scan_example_vuln) { 'Prototype pollution attack in mixin-deep' }
      let(:container_scan_example_vuln) { 'CVE-2017-18269 in glibc' }
      let(:sast_scan_example_vuln) { 'Cipher with no integrity' }
      let(:dast_scan_example_vuln) { 'Flask debug mode identified on target:7777' }
      let(:sast_scan_fp_example_vuln) { "Possible unprotected redirect" }
      let(:sast_scan_fp_example_vuln_desc) { "Possible unprotected redirect near line 46" }
      let(:secret_detection_vuln) { "Typeform API token" }

      let!(:gitlab_ci_yaml_path) { File.join(EE::Runtime::Path.fixture('secure_premade_reports'), '.gitlab-ci.yml') }
      let!(:dependency_report_json) do
        File.join(EE::Runtime::Path.fixture('secure_premade_reports'), 'gl-dependency-scanning-report.json')
      end

      let!(:ci_yaml_content) do
        original_yaml = File.read(gitlab_ci_yaml_path)
        original_yaml << "\n"
        original_yaml << <<~YAML
          secret_detection:
            tags: [secure_report]
            script:
              - echo "Skipped"
            artifacts:
              reports:
                secret_detection: gl-secret-detection-report.json
        YAML
      end

      let(:group) { create(:group, path: "govern-security-reports-#{Faker::Alphanumeric.alphanumeric(number: 6)}") }
      let!(:dependency_scan_yaml) do
        <<~YAML
          dependency_scanning:
            tags: [secure_report]
            script:
              - echo "Skipped"
            artifacts:
              reports:
                dependency_scanning: gl-dependency-scanning-report.json
        YAML
      end

      let!(:project) do
        create(:project, name: 'project-with-secure', description: 'Project with Secure', group: group)
      end

      let!(:runner) do
        create(:project_runner, project: project, name: "runner-for-#{project.name}", tags: ['secure_report'])
      end

      before do
        Flow::Login.sign_in_unless_signed_in
        project.visit!
      end

      after do
        runner&.remove_via_api! if runner
      end

      it 'dependency list has empty state',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348004' do
        Page::Project::Menu.perform(&:go_to_dependency_list)

        EE::Page::Project::Secure::DependencyList.perform do |dependency_list|
          expect(dependency_list).to have_empty_state_description(
            'The dependency list details information about the components used within your project.'
          )
          expect(dependency_list).to have_link(
            'More Information',
            href: %r{/help/user/application_security/dependency_list/index}
          )
        end
      end

      it 'displays security reports in the pipeline',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348036' do
        push_security_reports
        project.visit!
        wait_for_pipeline_success
        Flow::Pipeline.visit_latest_pipeline
        Page::Project::Pipeline::Show.perform do |pipeline|
          pipeline.click_on_security

          filter_report_and_perform(page: pipeline, filter_report: "Dependency Scanning") do
            expect(pipeline).to have_vulnerability_info_content dependency_scan_example_vuln
          end

          filter_report_and_perform(page: pipeline, filter_report: "Container Scanning") do
            expect(pipeline).to have_vulnerability_info_content container_scan_example_vuln
          end

          filter_report_and_perform(page: pipeline, filter_report: "SAST") do
            expect(pipeline).to have_vulnerability_info_content sast_scan_example_vuln
            expect(pipeline).to have_vulnerability_info_content sast_scan_fp_example_vuln
          end

          filter_report_and_perform(page: pipeline, filter_report: "DAST") do
            expect(pipeline).to have_vulnerability_info_content dast_scan_example_vuln
          end

          filter_report_and_perform(page: pipeline, filter_report: "Secret Detection") do
            expect(pipeline).to have_vulnerability_info_content secret_detection_vuln
          end
        end
      end

      it 'displays security reports in the project security dashboard',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348037' do
        push_security_reports
        project.visit!
        wait_for_pipeline_success
        Page::Project::Menu.perform(&:click_project)
        Page::Project::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Project::Secure::SecurityDashboard.perform(&:wait_for_vuln_report_to_load)

        EE::Page::Project::Secure::Show.perform do |dashboard|
          filter_report_and_perform(page: dashboard, filter_report: "Dependency Scanning") do
            expect(dashboard).to have_vulnerability dependency_scan_example_vuln
          end

          filter_report_and_perform(page: dashboard, filter_report: "Container Scanning") do
            expect(dashboard).to have_vulnerability container_scan_example_vuln
          end

          filter_report_and_perform(page: dashboard, filter_report: "SAST") do
            expect(dashboard).to have_vulnerability sast_scan_example_vuln
            expect(dashboard).to have_vulnerability sast_scan_fp_example_vuln
            expect(dashboard).to have_false_positive_vulnerability
          end

          filter_report_and_perform(page: dashboard, filter_report: "DAST") do
            expect(dashboard).to have_vulnerability dast_scan_example_vuln
          end

          filter_report_and_perform(page: dashboard, filter_report: "Secret Detection") do
            expect(dashboard).to have_vulnerability secret_detection_vuln
          end
        end
      end

      it 'displays security reports in the group security dashboard',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348038' do
        push_security_reports
        project.visit!
        wait_for_pipeline_success

        project.group.visit!

        Page::Group::Menu.perform(&:go_to_security_dashboard)

        EE::Page::Group::Secure::Show.perform do |dashboard|
          Support::Retrier.retry_on_exception(
            max_attempts: 2,
            reload_page: page,
            message: "Retry project security status in security dashboard"
          ) do
            expect(dashboard).to have_security_status_project_for_severity('F', project)
          end
        end

        Page::Group::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Group::Secure::Show.perform do |dashboard|
          dashboard.filter_project(project.id)

          filter_report_and_perform(page: dashboard, filter_report: "Dependency Scanning") do
            expect(dashboard).to have_vulnerability dependency_scan_example_vuln
          end

          filter_report_and_perform(page: dashboard, filter_report: "Container Scanning") do
            expect(dashboard).to have_vulnerability container_scan_example_vuln
          end

          filter_report_and_perform(page: dashboard, filter_report: "SAST") do
            expect(dashboard).to have_vulnerability sast_scan_example_vuln
          end

          filter_report_and_perform(page: dashboard, filter_report: "DAST") do
            expect(dashboard).to have_vulnerability dast_scan_example_vuln
          end

          filter_report_and_perform(page: dashboard, filter_report: "Secret Detection") do
            expect(dashboard).to have_vulnerability secret_detection_vuln
          end
        end
      end

      it 'displays false positives for the vulnerabilities',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/350412' do
        push_security_reports
        project.visit!
        wait_for_pipeline_success

        Page::Project::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Project::Secure::SecurityDashboard.perform(&:wait_for_vuln_report_to_load)

        EE::Page::Project::Secure::Show.perform do |security_dashboard|
          security_dashboard.filter_report_type("SAST") do
            expect(security_dashboard).to have_vulnerability sast_scan_fp_example_vuln
          end
        end

        EE::Page::Project::Secure::SecurityDashboard.perform do |security_dashboard|
          Support::Retrier.retry_on_exception(
            max_attempts: 2,
            sleep_interval: 3,
            reload_page: page,
            message: 'False positive vuln retry'
          ) do
            security_dashboard.click_vulnerability(description: sast_scan_fp_example_vuln)
          end
        end

        EE::Page::Project::Secure::VulnerabilityDetails.perform do |vulnerability_details|
          aggregate_failures "testing False positive vulnerability details" do
            expect(vulnerability_details).to have_component(component_name: "vulnerability-header")
            expect(vulnerability_details).to have_component(component_name: "vulnerability-details")
            expect(vulnerability_details).to have_vulnerability_title(title: sast_scan_fp_example_vuln)
            expect(vulnerability_details).to have_vulnerability_description(description: sast_scan_fp_example_vuln_desc)
            expect(vulnerability_details).to have_component(component_name: "vulnerability-footer")
            expect(vulnerability_details).to have_component(component_name: "false-positive-alert")
          end
        end
      end

      context 'for dependency scanning' do
        it(
          'displays the Dependency List',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348035'
        ) do
          commit_scan_files(fixture_json: dependency_report_json, ci_yaml_content: dependency_scan_yaml)
          project.visit!
          wait_for_pipeline_success
          Page::Project::Menu.perform(&:go_to_dependency_list)

          validate_dependency_list(number_of_dependencies_dependency_scanning)
        end
      end

      def validate_dependency_list(expected_count_of_dependencies)
        EE::Page::Project::Secure::DependencyList.perform do |dependency_list|
          Support::Retrier.retry_on_exception(
            max_attempts: 3,
            reload_page: page,
            message: "Retrying for dependency list count",
            sleep_interval: 2
          ) do
            expect(dependency_list).to have_dependency_count_of expected_count_of_dependencies
          end
        end
      end

      def filter_report_and_perform(page:, filter_report:)
        page.filter_report_type(filter_report)
        yield
        page.filter_report_type(filter_report) # Disable filter to avoid combining
      end

      def push_security_reports
        build(:commit,
          project: project,
          commit_message: 'Create Secure compatible application to serve premade reports') do |commit|
            commit.add_directory(Pathname.new(EE::Runtime::Path.fixture('dismissed_security_findings_mr_widget')))
            commit.add_directory(Pathname.new(EE::Runtime::Path.fixture('secure_premade_reports')))
            commit.update_files([ci_file])
          end.fabricate_via_api!
      end

      def commit_scan_files(fixture_json:, ci_yaml_content:)
        create(:commit, project: project, commit_message: 'Commit dependency scanning files', actions: [
          { action: 'create', file_path: File.basename(fixture_json), content: File.read(fixture_json) },
          { action: 'create', file_path: '.gitlab-ci.yml', content: ci_yaml_content }
        ])
      end

      def wait_for_pipeline_success
        Support::Waiter.wait_until(sleep_interval: 10, message: "Check for pipeline success") do
          latest_pipeline.status == 'success'
        end
      end

      def latest_pipeline
        Support::Waiter.wait_until(sleep_interval: 2, message: "Waiting for pipelines api endpoint to populate") do
          !project.pipelines.empty?
        end
        create(:pipeline, project: project, id: project.latest_pipeline[:id]) # Fetch existing pipeline object
      end

      def ci_file
        {
          file_path: '.gitlab-ci.yml',
          content: ci_yaml_content
        }
      end
    end
  end
end
