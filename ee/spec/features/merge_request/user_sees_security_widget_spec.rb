# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Merge request > User sees security widget",
  :js, :sidekiq_inline, :use_clean_rails_memory_store_caching,
  feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let(:merge_request) { create(:merge_request, :simple, :with_sast_reports, source_project: project) }
  let(:user) { project.creator }

  let(:feature_branch_start_sha) { "ae73cb07c9eeaf35924a10f713b364d32b2dd34f" }
  let(:mr_widget_app_selector) { "[data-testid='mr-widget-app']" }
  let(:merge_request_path) { project_merge_request_path(project, merge_request) }

  before do
    stub_licensed_features(
      security_dashboard: true,
      sast: true
    )

    project.add_developer(user)
    sign_in(user)
  end

  it "shows the security widget" do
    visit(merge_request_path)

    page.within(mr_widget_app_selector) do
      expect(page).to have_content(
        "Security scanning detected 5 new potential vulnerabilities"
      )

      click_on 'Show details'

      expect(page).to have_content 'Hard coded key'
    end
  end

  context "when vulnerabilities in an MR have already been detected on main" do
    let!(:ci_pipeline) do
      create(
        :ci_pipeline,
        :success,
        :with_sast_report,
        project: project,
        sha: feature_branch_start_sha
      )
    end

    it "does not show them as new vulnerabilities" do
      visit(merge_request_path)

      page.within(mr_widget_app_selector) do
        expect(page).to have_content(
          "Security scanning detected no new potential vulnerabilities"
        )
      end
    end
  end

  context "when master detects vulnerabilities in a child pipeline" do
    context 'and merge request detects the same vulnerabilities not in a child pipeline' do
      let(:parent_pipeline) do
        create(
          :ci_pipeline,
          :success,
          project: project,
          sha: feature_branch_start_sha
        )
      end

      let!(:child_pipeline) do
        create(
          :ci_pipeline,
          :success,
          :with_sast_report,
          project: project,
          child_of: parent_pipeline,
          sha: feature_branch_start_sha
        )
      end

      it "does not show them as new vulnerabilities" do
        visit(merge_request_path)

        page.within(mr_widget_app_selector) do
          expect(page).to have_content(
            "Security scanning detected no new potential vulnerabilities"
          )
        end
      end
    end
  end

  describe 'dismissal descriptions' do
    let(:dismissal_descriptions_json) do
      # Use dynamic translations via N_(...)
      {
        acceptable_risk: _("The vulnerability is known, and has not been remediated or mitigated, " \
                           "but is considered to be an acceptable business risk."),
        false_positive: _("An error in reporting in which a test result incorrectly indicates " \
                          "the presence of a vulnerability in a system when the vulnerability is not present."),
        mitigating_control: _("A management, operational, or technical control (that is, safeguard " \
                              "or countermeasure) employed by an organization that provides equivalent " \
                              "or comparable protection for an information system."),
        used_in_tests: _("The finding is not a vulnerability because it is part of a test or is test data."),
        not_applicable: _("The vulnerability is known, and has not been remediated or mitigated, but is " \
                          "considered to be in a part of the application that will not be updated.")
      }.to_json
    end

    it 'loads dismissal descriptions' do
      visit(merge_request_path)
      expect(page.evaluate_script('window.gl.mrWidgetData.dismissal_descriptions')).to match(
        dismissal_descriptions_json
      )
    end
  end

  it 'sets commit_path_template' do
    visit(merge_request_path)
    expect(page.evaluate_script('window.gl.mrWidgetData.commit_path_template')).to eq(
      "/#{project.path_with_namespace}/-/commit/$COMMIT_SHA"
    )
  end
end
