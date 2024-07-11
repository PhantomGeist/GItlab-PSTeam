# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User creates issue", :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project_empty_repo, :public, namespace: group) }
  let_it_be(:epic) { create(:epic, group: group, title: 'Sample epic', author: user) }
  let_it_be(:iteration) { create(:iteration, group: group, title: 'Sample iteration') }

  let(:issue_title) { '500 error on profile' }

  before_all do
    group.add_developer(user)
  end

  before do
    stub_licensed_features(issue_weights: true)
    stub_licensed_features(epics: true)

    sign_in(user)

    visit(new_project_issue_path(project))
  end

  context "when user can use AI to generate description" do
    before do
      stub_licensed_features(generate_description: true)
      stub_feature_flags(openai_experimentation: true)
      project.group.root_ancestor.namespace_settings.update_attribute(:experiment_features_enabled, true)

      sign_in(user)

      visit new_project_issue_path(project)
    end

    it 'has the AI actions button' do
      expect(page).to have_button('AI actions')
    end
  end

  context 'when user cannot use AI to generate description' do
    using RSpec::Parameterized::TableSyntax

    where(:generate_description, :openai_experimentation, :experiment_features_enabled) do
      true  | false | false
      true  | true  | false
      true  | false | true
      false | true  | true
      false | true  | false
      false | false | true
      false | false | false
    end

    with_them do
      before do
        stub_licensed_features(generate_description: generate_description)
        stub_feature_flags(openai_experimentation: openai_experimentation)
        project.group.root_ancestor.namespace_settings.update_attribute(:experiment_features_enabled,
          experiment_features_enabled)

        sign_in(user)

        visit new_project_issue_path(project)
      end

      it 'does not have the AI actions button' do
        expect(page).not_to have_button('AI actions')
      end
    end
  end

  context "with weight set" do
    it "creates issue" do
      weight = "7"

      fill_in("Title", with: issue_title)
      fill_in("issue_weight", with: weight)

      click_button 'Create issue'

      page.within(".weight") do
        expect(page).to have_content(weight)
      end

      expect(page).to have_content(issue_title)
    end
  end

  context 'with epics' do
    before do
      fill_in("Title", with: issue_title)
    end

    it 'creates an issue with no epic' do
      click_button 'Select epic'
      click_on 'No epic'
      click_button 'Create issue'

      wait_for_all_requests

      within_testid('select-epic') do
        expect(page).to have_content('None')
      end

      expect(page).to have_content(issue_title)
    end

    it 'creates an issue with an epic' do
      click_button 'Select epic'
      click_on epic.title
      click_button 'Create issue'

      wait_for_all_requests

      within_testid('select-epic') do
        expect(page).to have_content(epic.title)
      end

      expect(page).to have_content(issue_title)
    end
  end

  context 'with iterations' do
    before do
      fill_in("Title", with: issue_title)
    end

    it 'creates an issue with no iteration' do
      click_button 'Select iteration'
      select_listbox_item 'No iteration'

      expect(page).to have_button('Select iteration')

      click_button 'Create issue'

      wait_for_all_requests

      within_testid('select-iteration') do
        expect(page).to have_content('None')
      end

      expect(page).to have_content(issue_title)
    end

    it 'creates an issue with an iteration' do
      click_button 'Select iteration'
      select_listbox_item(iteration.title)

      expect(page).to have_button(iteration.period)

      click_button 'Create issue'

      wait_for_all_requests

      within_testid('select-iteration') do
        expect(page).to have_content(iteration.title)
      end

      expect(page).to have_content(issue_title)
    end
  end

  context 'when new issue url has parameter' do
    context 'for inherited issue template' do
      let_it_be(:template_project) { create(:project, :public, :repository) }

      before do
        template_project.repository.create_file(
          user,
          '.gitlab/issue_templates/bug.md',
          'this is a test "bug" template',
          message: 'added issue template',
          branch_name: 'master')

        group.add_owner(user)
        stub_licensed_features(custom_file_templates_for_namespace: true)
        create(:project_group_link, project: template_project, group: group)
        group.update!(file_template_project_id: template_project.id)

        visit new_project_issue_path(project, issuable_template: 'bug')
      end

      it 'fills in with inherited template' do
        expect(find('.js-issuable-selector .dropdown-toggle-text')).to have_content('bug')
      end
    end
  end
end
