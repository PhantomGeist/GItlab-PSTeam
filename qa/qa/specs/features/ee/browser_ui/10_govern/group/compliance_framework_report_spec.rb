# frozen_string_literal: true

module QA
  RSpec.describe 'Govern', :skip_live_env, product_group: :compliance do
    describe 'Compliance Framework Report' do
      let!(:subgroup) { create(:group, path: "compliance-#{Faker::Alphanumeric.alphanumeric(number: 8)}") }

      let!(:top_level_project) do
        create(:project, name: 'project-compliance-framework-report', group: subgroup.sandbox)
      end

      let!(:project_without_framework) do
        create(:project, name: 'project-without-compliance-framework', group: subgroup.sandbox)
      end

      let!(:subgroup_project) do
        create(:project, name: 'subgroup-project-compliance-framework-report', group: subgroup)
      end

      let!(:default_compliance_framework) do
        QA::EE::Resource::ComplianceFramework.fabricate_via_api! do |framework|
          framework.group = subgroup.sandbox
          framework.default = true
        end
      end

      let!(:another_framework) do
        QA::EE::Resource::ComplianceFramework.fabricate_via_api! do |framework|
          framework.group = subgroup
        end
      end

      before do
        Flow::Login.sign_in

        # Apply different compliance frameworks to two projects so that we can confirm their correct assignment
        top_level_project.compliance_framework = default_compliance_framework
        subgroup_project.compliance_framework = another_framework
      end

      after do
        # Remove now because the cleanup tool can't remove GraphQL resources yet
        default_compliance_framework.remove_via_api!(delete_default: true)
        another_framework.remove_via_api!

        # Clean up all compliance frameworks, just in case previous previous attempts (e.g. retries) left some behind
        subgroup.sandbox.compliance_frameworks.each { |framework| framework.remove_via_api!(delete_default: true) }
      end

      it(
        'shows the compliance framework for each project', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/396600'
      ) do
        subgroup.sandbox.visit!
        Page::Group::Menu.perform(&:go_to_compliance_center)
        QA::EE::Page::Group::Compliance::Show.perform do |report|
          report.click_projects_tab

          aggregate_failures do
            report.project_row(top_level_project) do |project|
              expect(project).to have_name(top_level_project.name)
              expect(project).to have_path(top_level_project.full_path)
              expect(project).to have_framework(default_compliance_framework.name, default: true)
            end

            report.project_row(subgroup_project) do |project|
              expect(project).to have_name(subgroup_project.name)
              expect(project).to have_path(subgroup_project.full_path)
              expect(project).to have_framework(another_framework.name, default: false)
            end

            report.project_row(project_without_framework) do |project|
              expect(project).to have_name(project_without_framework.name)
              expect(project).to have_path(project_without_framework.full_path)
              expect(project).not_to have_framework
            end
          end
        end
      end
    end
  end
end
