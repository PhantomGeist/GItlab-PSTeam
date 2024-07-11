# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'Group file templates', :requires_admin, product_group: :source_code do
      include Support::API

      templates = [
        {
          file_name: 'Dockerfile',
          template: 'custom_dockerfile',
          action: 'create',
          file_path: 'Dockerfile/custom_dockerfile.dockerfile',
          content: 'dockerfile template test',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347656'
        },
        {
          file_name: '.gitignore',
          template: 'custom_gitignore',
          action: 'create',
          file_path: 'gitignore/custom_gitignore.gitignore',
          content: 'gitignore template test',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347655'
        },
        {
          file_name: '.gitlab-ci.yml',
          template: 'custom_gitlab-ci',
          action: 'create',
          file_path: 'gitlab-ci/custom_gitlab-ci.yml',
          content: 'gitlab-ci.yml template test',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347653'
        },
        {
          file_name: 'LICENSE',
          template: 'custom_license',
          action: 'create',
          file_path: 'LICENSE/custom_license.txt',
          content: 'license template test',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347654'
        }
      ]

      let(:api_client) do
        Runtime::API::Client.as_admin
      end

      let(:group) { create(:group, path: 'template-group', api_client: api_client) }

      let(:file_template_project) do
        create(:project,
          :with_readme,
          name: 'group-file-template-project',
          description: 'Add group file templates',
          group: group,
          api_client: api_client)
      end

      let(:project) do
        create(:project,
          :with_readme,
          name: 'group-file-template-project-2',
          description: 'Add files for group file templates',
          group: group,
          api_client: api_client)
      end

      templates.each do |template|
        it "creates file via custom #{template[:file_name]} file template", testcase: template[:testcase] do
          api_client.personal_access_token

          create(:commit,
            project: file_template_project,
            commit_message: 'Add group file templates',
            api_client: api_client,
            actions: templates)

          Flow::Login.sign_in_as_admin

          set_file_template_if_not_already_set

          project.visit!

          Page::Project::Show.perform(&:create_new_file!)
          Page::File::Form.perform do |form|
            Support::Retrier.retry_until do
              form.add_custom_name(template[:file_name])
              form.select_template template[:file_name], template[:template]

              form.has_normalized_ws_text?(template[:content])
            end
            form.commit_changes

            aggregate_failures "indications of file created" do
              expect(form).to have_content(template[:file_name])
              expect(form).to have_normalized_ws_text(template[:content].chomp)
              expect(form).to have_content('Add new file')
            end
          end

          remove_group_file_template_if_set
        end
      end

      def set_file_template_if_not_already_set
        response = get Runtime::API::Request.new(api_client, "/groups/#{group.id}").url

        return if parse_body(response)[:file_template_project_id]

        group.visit!
        Page::Group::Menu.perform(&:go_to_general_settings)
        Page::Group::Settings::General.perform do |general|
          general.choose_file_template_repository(file_template_project.name)
        end
      end

      def remove_group_file_template_if_set
        response = get Runtime::API::Request.new(api_client, "/groups/#{group.id}").url

        if parse_body(response)[:file_template_project_id]
          put Runtime::API::Request.new(api_client, "/groups/#{group.id}").url, { file_template_project_id: nil }
        end
      end
    end
  end
end
