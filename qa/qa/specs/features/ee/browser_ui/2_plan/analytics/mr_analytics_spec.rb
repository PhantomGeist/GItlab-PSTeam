# frozen_string_literal: true

module QA
  RSpec.describe 'Plan' do
    describe 'Merge Request Analytics', :reliable, :requires_admin, product_group: :optimize do
      let(:label) { "mr-label" }
      let(:admin_api_client) { Runtime::API::Client.as_admin }
      let(:user_api_client) { Runtime::API::Client.new(user: user) }

      let(:user) { create(:user, api_client: admin_api_client) }

      let(:group) { create(:group, path: "mr-analytics-#{SecureRandom.hex(8)}") }

      let(:project) { create(:project, name: 'mr_analytics', group: group, api_client: admin_api_client) }

      let(:mr_1) do
        create(:merge_request,
          title: 'First merge request',
          labels: [label],
          project: project,
          api_client: user_api_client)
      end

      let(:mr_2) do
        create(:merge_request,
          title: 'Second merge request',
          project: project,
          api_client: user_api_client)
      end

      before do
        group.add_member(user, Resource::Members::AccessLevel::MAINTAINER)

        create(:project_label, project: project, title: label, api_client: user_api_client)

        mr_2.add_comment(body: "This is mr comment")
        mr_1.merge_via_api!
        mr_2.merge_via_api!

        Flow::Login.sign_in(as: user)
        project.visit!
        Page::Project::Menu.perform(&:go_to_merge_request_analytics)
      end

      it(
        "shows merge request analytics chart and stats",
        testcase: "https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/416723"
      ) do
        EE::Page::Project::MergeRequestAnalytics.perform do |mr_analytics_page|
          expect(mr_analytics_page.throughput_chart).to be_visible
          # chart elements will be loaded even when no data is fetched,
          # so explicit check for missing no data warning is required
          expect(mr_analytics_page).not_to(
            have_content("There is no chart data available"),
            "Expected chart data to be available"
          )

          aggregate_failures do
            expect(mr_analytics_page.mean_time_to_merge).to eq("0 days")
            expect(mr_analytics_page.merged_mrs(expected_count: 2)).to match_array([
              {
                title: mr_1.title,
                label_count: 1,
                comment_count: 0
              },
              {
                title: mr_2.title,
                label_count: 0,
                comment_count: 1
              }
            ])
          end
        end
      end
    end
  end
end
