# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group elastic search', :js, :elastic, :sidekiq_inline, :disable_rate_limiter,
  feature_category: :global_search do
  let_it_be(:user) { create(:user) }

  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, :wiki_repo, namespace: group) }

  def choose_group(group)
    find('[data-testid="group-filter"]').click
    wait_for_requests

    page.within '[data-testid="group-filter"]' do
      click_button group.name
    end
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

    project.add_maintainer(user)
    group.add_owner(user)

    sign_in(user)

    visit(search_path)

    wait_for_requests

    choose_group(group)
  end

  describe 'issue search' do
    before do
      create(:issue, project: project, title: 'chosen issue title')

      ensure_elasticsearch_index!
    end

    it 'finds the issue' do
      submit_search('chosen')
      select_search_scope('Issues')

      expect(page).to have_content('chosen issue title')
    end
  end

  describe 'blob search' do
    before do
      project.repository.index_commits_and_blobs

      ensure_elasticsearch_index!
    end

    it 'finds files' do
      submit_search('def')
      select_search_scope('Code')

      expect(page).to have_selector('.file-content .code')
      expect(page).to have_button('Copy file path')
    end
  end

  describe 'wiki search' do
    include WikiHelpers
    let(:wiki) { ProjectWiki.new(project, user) }
    let(:group_wiki) { create(:group_wiki, group: group) }

    before do
      stub_group_wikis(true)
      [group_wiki, wiki].each do |w|
        w.create_page('test.md', '# term')
        w.index_wiki_blobs
      end
      ensure_elasticsearch_index!
    end

    it 'finds Project and Group wiki pages' do
      submit_search('term')
      select_search_scope('Wiki')

      expect(page).to have_selector('.search-result-row .description', text: 'term').twice
      expect(page).to have_link('test').twice
    end
  end

  describe 'epic search' do
    before do
      stub_licensed_features(epics: true)

      create(:epic, group: group, title: 'chosen epic title')

      ensure_elasticsearch_index!
    end

    it 'finds the epic' do
      submit_search('chosen')
      select_search_scope('Epics')

      expect(page).to have_content('chosen epic title')
    end
  end

  describe 'commit search' do
    before do
      project.repository.index_commits_and_blobs
      ensure_elasticsearch_index!
    end

    it 'finds commits' do
      submit_search('add')
      select_search_scope('Commits')

      expect(page).to have_selector('.commit-list > .commit')
    end
  end
end

RSpec.describe 'Group elastic search redactions', feature_category: :global_search do
  it_behaves_like 'a redacted search results page' do
    let(:search_path) { group_path(public_group) }
  end
end
