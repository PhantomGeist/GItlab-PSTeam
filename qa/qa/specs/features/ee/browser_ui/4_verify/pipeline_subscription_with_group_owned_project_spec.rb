# frozen_string_literal: true

module QA
  RSpec.describe 'Verify' do
    describe 'Pipeline subscription with a group owned project', :runner, product_group: :pipeline_execution do
      let(:executor) { "qa-runner-#{SecureRandom.hex(3)}" }
      let(:tag_name) { "awesome-tag-#{SecureRandom.hex(3)}" }
      let(:group) { create(:group, name: "group-for-pipeline-subscriptions-#{SecureRandom.hex(3)}") }

      let(:upstream_project) do
        create(:project,
          name: 'upstream-project-for-subscription',
          description: 'Project with CI subscription',
          group: group)
      end

      let(:downstream_project) do
        create(:project,
          name: 'project-with-pipeline-subscription',
          description: 'Project with CI subscription',
          group: group)
      end

      let!(:runner) do
        Resource::GroupRunner.fabricate! do |runner|
          runner.group = group
          runner.name = executor
          runner.tags = [executor]
        end
      end

      before do
        [downstream_project, upstream_project].each do |project|
          add_ci_file(project)
        end

        Flow::Login.sign_in
        downstream_project.visit!

        EE::Resource::PipelineSubscriptions.fabricate_via_browser_ui! do |subscription|
          subscription.project_path = upstream_project.path_with_namespace
        end
      end

      after do
        [runner, upstream_project, downstream_project, group].each do |item|
          item.remove_via_api!
        end
      end

      context 'when upstream project new tag pipeline finishes' do
        it 'triggers pipeline in downstream project', :reliable,
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347998' do
          # Downstream project should have one pipeline at this time
          Support::Waiter.wait_until { downstream_project.pipelines.size == 1 }

          create(:tag, project: upstream_project, ref: upstream_project.default_branch, name: tag_name)

          downstream_project.visit!

          Support::Waiter.wait_until(sleep_interval: 3) do
            QA::Runtime::Logger.info 'Waiting for upstream pipeline to succeed.'
            new_pipeline = upstream_project.pipelines.find { |pipeline| pipeline[:ref] == tag_name }
            new_pipeline&.dig(:status) == 'success'
          end

          Page::Project::Menu.perform(&:go_to_pipelines)

          # Downstream project must have 2 pipelines at this time
          expect { downstream_project.pipelines.size }.to eventually_eq(2), "There are currently #{downstream_project.pipelines.size} pipelines in downstream project."

          # expect new downstream pipeline to also succeed
          Page::Project::Pipeline::Index.perform do |index|
            expect(index.wait_for_latest_pipeline(status: 'Passed')).to be_truthy, 'Downstream pipeline did not succeed as expected.'
          end
        end
      end

      private

      def add_ci_file(project)
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              job:
                tags:
                  - #{executor}
                script:
                  - echo DONE!
            YAML
          }
        ])
      end
    end
  end
end
