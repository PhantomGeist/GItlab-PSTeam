# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'Batch comments in merge request', :reliable, product_group: :code_review do
      let(:project) { create(:project, name: 'project-with-merge-request') }
      let(:merge_request) do
        create(:merge_request, title: 'This is a merge request', description: 'Great feature', project: project)
      end

      it 'user submits a non-diff review', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347777' do
        Flow::Login.sign_in

        merge_request.visit!

        Page::MergeRequest::Show.perform do |show|
          show.click_discussions_tab

          # You can't start a review immediately, so we have to add a
          # comment (or start a thread) first
          show.start_discussion("I'm starting a new discussion")
          show.type_reply_to_discussion(1, "Could you please check this?")
          show.start_review
          show.submit_pending_reviews

          expect(show).to have_comment("I'm starting a new discussion")
          expect(show).to have_comment("Could you please check this?")
          expect(show).to have_content("1 unresolved thread")
        end
      end

      it 'user submits a diff review', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347778' do
        Flow::Login.sign_in

        merge_request.visit!

        Page::MergeRequest::Show.perform do |show|
          show.click_diffs_tab
          show.add_comment_to_diff("Can you check this line of code?")
          show.start_review
          show.submit_pending_reviews
        end

        # Overwrite the added file to create a system note as required to
        # trigger the bug described here: https://gitlab.com/gitlab-org/gitlab/issues/32157
        commit_message = 'Update file'
        create(:commit,
          project: project,
          commit_message: commit_message,
          branch: merge_request.source_branch, actions: [
            { action: 'update', file_path: merge_request.file_name, content: "File updated" }
          ])
        project.wait_for_push(commit_message)

        Page::MergeRequest::Show.perform do |show|
          show.click_discussions_tab
          show.resolve_discussion_at_index(0)

          expect(show).to have_comment("Can you check this line of code?")
          expect(show).to have_content("All threads resolved")
        end
      end
    end
  end
end
