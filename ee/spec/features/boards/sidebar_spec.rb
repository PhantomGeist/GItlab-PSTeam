# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issue Boards', :js, feature_category: :team_planning do
  include BoardHelpers

  let_it_be(:user)         { create(:user) }
  let_it_be(:user2)        { create(:user) }

  let_it_be(:group)        { create(:group) }
  let_it_be(:project)      { create(:project, :public, group: group) }

  let_it_be(:milestone)    { create(:milestone, project: project) }
  let_it_be(:development)  { create(:label, project: project, name: 'Development') }
  let_it_be(:stretch)      { create(:label, project: project, name: 'Stretch') }
  let_it_be(:scoped_label_1) { create(:label, project: project, name: 'Scoped1::Label1') }
  let_it_be(:scoped_label_2) { create(:label, project: project, name: 'Scoped2::Label2') }

  let_it_be(:issue1)       { create(:labeled_issue, project: project, assignees: [user], milestone: milestone, labels: [development], weight: 3, relative_position: 2) }
  let_it_be(:issue2)       { create(:labeled_issue, project: project, labels: [development, stretch], relative_position: 1) }
  let_it_be(:epic1) { create(:epic, group: group, title: 'Foo') }
  let_it_be(:epic2) { create(:epic, group: group, title: 'Bar') }
  let_it_be(:epic_issue) { create(:epic_issue, issue: issue2, epic: epic1) }

  let_it_be(:board)        { create(:board, project: project) }
  let_it_be(:list)         { create(:list, board: board, label: development, position: 0) }

  let(:card1) { find('.board:nth-child(2)').find('.board-card:nth-child(2)') }
  let(:card2) { find('.board:nth-child(2)').find('.board-card:nth-child(1)') }

  before do
    stub_feature_flags(apollo_boards: false)
    stub_licensed_features(multiple_issue_assignees: true)

    project.add_maintainer(user)
    project.team.add_developer(user2)

    sign_in user

    visit_project_board
  end

  context 'assignee', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/332078' do
    let(:assignees_widget) { '[data-testid="issue-boards-sidebar"] [data-testid="assignees-widget"]' }

    it 'updates the issues assignee' do
      click_card(card2)

      page.within(assignees_widget) do
        click_button('Edit')
        wait_for_requests

        assignee = first('.gl-avatar-labeled').find('.gl-avatar-labeled-label').text

        page.within('.dropdown-menu-user') do
          first('.gl-avatar-labeled').click
        end

        click_button('Apply')
        wait_for_requests

        expect(page).to have_content(assignee)
      end

      expect(card2).to have_selector('.avatar')
    end

    it 'adds multiple assignees' do
      click_card(card1)

      page.within(assignees_widget) do
        click_button('Edit')
        wait_for_requests

        assignee = all('.gl-avatar-labeled')[1].find('.gl-avatar-labeled-label').text

        page.within('.dropdown-menu-user') do
          find_by_testid('unassign').click

          all('.gl-avatar-labeled')[0].click
          all('.gl-avatar-labeled')[1].click
        end

        click_button('Apply')
        wait_for_requests

        aggregate_failures do
          expect(page).to have_link(nil, title: user.name)
          expect(page).to have_link(nil, title: assignee)
        end
      end

      expect(card1.all('.avatar').length).to eq(2)
    end

    it 'removes the assignee' do
      click_card(card1)

      page.within(assignees_widget) do
        click_button('Edit')
        wait_for_requests

        page.within('.dropdown-menu-user') do
          find_by_testid('unassign').click
        end

        click_button('Apply')
        wait_for_requests

        expect(page).to have_content('None')
      end

      expect(card1).not_to have_selector('.avatar')
    end

    it 'assignees to current user' do
      click_card(card2)

      page.within(assignees_widget) do
        expect(page).to have_content('None')

        click_button 'assign yourself'

        wait_for_requests

        expect(page).to have_content(user.name)
      end

      expect(card2).to have_selector('.avatar')
    end

    it 'updates assignee dropdown' do
      click_card(card2)

      page.within(assignees_widget) do
        click_button('Edit')
        wait_for_requests

        assignee = first('.gl-avatar-labeled').find('.gl-avatar-labeled-label').text

        page.within('.dropdown-menu-user') do
          first('.gl-avatar-labeled').click
        end

        click_button('Apply')
        wait_for_requests

        expect(page).to have_content(assignee)
      end

      click_card(card1)

      page.within(assignees_widget) do
        click_button('Edit')

        expect(find('.dropdown-menu')).to have_selector('.gl-dropdown-item-check-icon')
      end
    end

    context 'when multiple assignees feature is not available' do
      before do
        stub_licensed_features(multiple_issue_assignees: false)

        visit_project_board
      end

      it 'does not allow selecting multiple assignees' do
        click_card(card1)

        page.within(assignees_widget) do
          click_button('Edit')

          first('.dropdown-menu-user .gl-avatar-labeled').click

          expect(page).to have_selector('.dropdown-menu', visible: false)
        end
      end
    end
  end

  context 'epic' do
    let(:epic_widget) { find_by_testid('sidebar-epic') }

    before do
      stub_licensed_features(epics: true)
      group.add_owner(user)

      visit_project_board
    end

    context 'when the issue is not associated with an epic' do
      it 'displays `None` for value of epic' do
        click_card(card1)

        expect(epic_widget.text).to have_content('None')
      end
    end

    context 'when the issue is associated with an epic' do
      it 'displays name of epic and links to it' do
        click_card(card2)

        expect(epic_widget).to have_link(epic1.title)
        expect(find_link(epic1.title)[:href]).to end_with(epic_path(epic1))
      end

      it 'updates the epic associated with the issue' do
        click_card(card2)

        within(epic_widget) do
          click_button 'Edit'
          wait_for_requests

          find('.gl-dropdown-item', text: epic2.title).click
          wait_for_requests

          expect(page).to have_content(epic2.title)
        end
      end
    end
  end

  context 'weight' do
    let(:weight_widget) { find_by_testid('sidebar-weight') }
    let(:weight_value) { find_by_testid('sidebar-weight-value') }

    it 'displays weight async' do
      click_card(card1)

      expect(weight_value).to have_content(issue1.weight)
    end

    it 'updates weight in sidebar to 1' do
      click_card(card1)

      within weight_widget do
        click_button 'Edit'
        find('.weight input').send_keys 1, :enter
      end

      expect(weight_value).to have_content '1'

      # Ensure the request was sent and things are persisted
      visit_project_board

      click_card(card1)

      expect(weight_value).to have_content '1'
    end

    it 'updates weight in sidebar to no weight' do
      click_card(card1)

      within weight_widget do
        click_button 'remove weight'
      end

      expect(weight_value).to have_content 'None'

      # Ensure the request was sent and things are persisted
      visit_project_board

      click_card(card1)

      expect(weight_value).to have_content 'None'
    end

    it 'updates the original card when another card is clicked' do
      click_card(card1)

      within weight_widget do
        click_button 'Edit'
        find('.weight input').send_keys 1
      end

      click_card(card2)
      click_card(card1)

      expect(weight_value).to have_content '1'
    end

    context 'unlicensed' do
      before do
        stub_licensed_features(issue_weights: false)

        visit_project_board
      end

      it 'hides weight' do
        click_card(card1)

        expect(page).not_to have_selector('[data-testid="sidebar-weight"]')
      end
    end
  end

  context 'scoped labels' do
    before do
      stub_licensed_features(scoped_labels: true)

      visit_project_board
    end

    it 'adds multiple scoped labels' do
      click_card(card1)

      within_testid('sidebar-labels') do
        click_button 'Edit'

        wait_for_requests

        click_button scoped_label_1.title

        wait_for_requests

        click_button scoped_label_2.title

        wait_for_requests

        click_button 'Close'

        page.within('.value') do
          aggregate_failures do
            expect(page).to have_selector('.gl-label-scoped', count: 2)
            expect(page).to have_content(scoped_label_1.scoped_label_key)
            expect(page).to have_content(scoped_label_1.scoped_label_value)
            expect(page).to have_content(scoped_label_2.scoped_label_key)
            expect(page).to have_content(scoped_label_2.scoped_label_value)
          end
        end
      end
    end

    context 'with scoped label assigned' do
      let!(:issue3) { create(:labeled_issue, project: project, labels: [development, scoped_label_1, scoped_label_2], relative_position: 3) }
      let(:card3) { find('.board:nth-child(2)').find('.board-card:nth-child(1)') }

      before do
        stub_licensed_features(scoped_labels: true)

        visit_project_board
      end

      it 'removes existing scoped label' do
        click_card(card3)

        within_testid('sidebar-labels') do
          click_button 'Edit'

          wait_for_requests

          click_button scoped_label_2.title

          wait_for_requests

          click_button 'Close'

          page.within('.value') do
            aggregate_failures do
              expect(page).to have_selector('.gl-label-scoped', count: 1)
              expect(page).not_to have_content(scoped_label_1.scoped_label_value)
              expect(page).to have_content(scoped_label_2.scoped_label_key)
              expect(page).to have_content(scoped_label_2.scoped_label_value)
            end
          end
        end

        aggregate_failures do
          expect(card3).to have_selector('.gl-label-scoped', count: 1)
          expect(card3).not_to have_content(scoped_label_1.scoped_label_key)
          expect(card3).not_to have_content(scoped_label_1.scoped_label_value)
          expect(card3).to have_content(scoped_label_2.scoped_label_key)
          expect(card3).to have_content(scoped_label_2.scoped_label_value)
        end
      end
    end
  end

  context 'when opening sidebars' do
    it 'closes card sidebar when opening settings sidebar' do
      click_card(card1)

      expect(page).to have_selector('[data-testid="issue-boards-sidebar"]')

      page.within(find('.board:nth-child(2)')) do
        find_button('Edit list settings').click
      end

      expect(page).to have_selector('.js-board-settings-sidebar')
      expect(page).not_to have_selector('[data-testid="issue-boards-sidebar"]')
    end

    it 'closes settings sidebar when opening card sidebar' do
      page.within(find('.board:nth-child(2)')) do
        find_button('Edit list settings').click
      end

      expect(page).to have_selector('.js-board-settings-sidebar')

      click_card(card1)

      expect(page).to have_selector('[data-testid="issue-boards-sidebar"]')
      expect(page).not_to have_selector('.js-board-settings-sidebar')
    end
  end

  def visit_project_board
    visit project_board_path(project, board)
    wait_for_requests
  end
end
