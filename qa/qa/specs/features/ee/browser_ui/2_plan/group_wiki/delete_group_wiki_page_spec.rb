# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', product_group: :knowledge do
    describe 'Testing group wiki' do
      let(:initial_wiki) { create(:group_wiki_page) }

      before do
        Flow::Login.sign_in
      end

      it 'can delete a group wiki page',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/374707' do
        initial_wiki.visit!

        EE::Page::Group::Wiki::Show.perform(&:click_edit)
        EE::Page::Group::Wiki::Edit.perform(&:delete_page)

        EE::Page::Group::Wiki::Show.perform do |wiki|
          expect(wiki).to have_no_page
        end
      end
    end
  end
end
