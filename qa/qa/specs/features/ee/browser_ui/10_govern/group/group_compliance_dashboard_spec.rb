# frozen_string_literal: true

module QA
  RSpec.describe 'Govern', :skip_live_env, product_group: :compliance do
    describe 'compliance dashboard' do
      let!(:approver1) { create(:user, name: "user1-compliance-dashboard-#{SecureRandom.hex(8)}") }
      let!(:approver1_api_client) { Runtime::API::Client.new(:gitlab, user: approver1) }
      let(:author_api_client) { Runtime::API::Client.new(:gitlab) }

      let(:number_of_approvals_violation) { "Less than 2 approvers" }
      let(:author_approval_violation) { "Approved by author" }
      let(:committer_approval_violation) { "Approved by committer" }

      let(:group) { create(:group, path: "test-group-compliance-#{SecureRandom.hex(8)}") }

      let!(:project) { create(:project, name: 'project-compliance-dashboard', group: group) }
      let(:merge_request) do
        create(:merge_request,
          project: project,
          title: "compliance-dashboard-mr-#{SecureRandom.hex(6)}",
          source_branch: "test-compliance-report-branch-#{SecureRandom.hex(8)}")
      end

      context 'with separation of duties in an MR' do
        before do
          project.update_approval_configuration(merge_requests_author_approval: true)
          project.add_member(approver1, Resource::Members::AccessLevel::MAINTAINER)
        end

        context 'when there is only one approval from a user other than the author' do
          before do
            merge_request.api_client = approver1_api_client
            merge_request.approve
            merge_request.merge_via_api!
            Flow::Login.sign_in
            merge_request.visit!
          end

          it 'shows only "less than two approvers" violation', :reliable,
            testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/390949' do
            group.visit!
            Page::Group::Menu.perform(&:go_to_compliance_center)
            QA::EE::Page::Group::Compliance::Show.perform do |compliance_center|
              compliance_center.switch_to_violations_tab

              expect(compliance_center).to have_violation("Less than 2 approvers", merge_request.title)
              expect(compliance_center).not_to have_violation(author_approval_violation, merge_request.title)
              expect(compliance_center).not_to have_violation(committer_approval_violation, merge_request.title)
            end
          end
        end

        context 'when there are two approvals but one of the approvers is the author' do
          before do
            merge_request.approve
            merge_request.api_client = approver1_api_client
            merge_request.approve
            merge_request.api_client = author_api_client
            merge_request.merge_via_api!
            Flow::Login.sign_in
            merge_request.visit!
          end

          it 'shows only "author approved merge request" and "approved by committer" violations', :reliable,
            testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/390948' do
            group.visit!
            Page::Group::Menu.perform(&:go_to_compliance_center)
            QA::EE::Page::Group::Compliance::Show.perform do |compliance_center|
              compliance_center.switch_to_violations_tab

              expect(compliance_center).not_to have_violation(number_of_approvals_violation, merge_request.title)
              expect(compliance_center).to have_violation(author_approval_violation, merge_request.title)
              expect(compliance_center).to have_violation(committer_approval_violation, merge_request.title)
            end
          end
        end
      end
    end
  end
end
