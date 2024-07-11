# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'OKR', :js, feature_category: :portfolio_management do
  include DragTo

  let(:user) { create(:user, :no_super_sidebar, name: 'Sherlock Holmes') }
  let(:user2) { create(:user, :no_super_sidebar, name: 'John') }
  let(:group) { create(:group, :public) }
  let(:project) { create(:project, :public, namespace: group) }
  let(:objective) { create(:work_item, :objective, project: project) }
  let!(:emoji_upvote) { create(:award_emoji, :upvote, awardable: objective, user: user2) }
  let(:key_result) { create(:work_item, :key_result, project: project) }
  let(:label) { create(:label, project: project, title: "testing-label") }
  let(:child_objective) { create(:work_item, :objective, project: project) }

  before do
    group.add_developer(user)

    sign_in(user)

    stub_licensed_features(okrs: true, issuable_health_status: true)
    stub_feature_flags(work_items: true, okrs_mvc: true)
  end

  shared_examples 'work items progress' do
    let(:form_selector) { '[data-testid="work-item-progress"]' }
    let(:input_selector) { '[data-testid="work-item-progress-input"]' }

    it 'successfully sets the progress' do
      find(input_selector).fill_in(with: '30')
      send_keys(:tab) # Simulate blur

      wait_for_requests

      expect(find(form_selector)).to have_content "30%"
      expect(work_item.reload.progress.progress).to eq 30
    end

    it 'prevents typing values outside min and max range', :aggregate_failures do
      page_body = page.find('body')
      page.within(form_selector) do
        progress_input = find(input_selector)
        progress_input.native.send_keys('101')
        page_body.click

        expect(progress_input.value).to eq('0')

        # Clear input
        progress_input.set('')
        progress_input.native.send_keys('-')
        page_body.click

        expect(progress_input.value).to eq('')
      end
    end

    it 'prevent typing special characters `+`, `-`, and `e`', :aggregate_failures do
      page_body = page.find('body')
      page.within(form_selector) do
        progress_input = find(input_selector)

        progress_input.native.send_keys('+')
        page_body.click
        expect(progress_input.value).to eq('0')

        progress_input.native.send_keys('-')
        page_body.click
        expect(progress_input.value).to eq('0')

        progress_input.native.send_keys('e')
        page_body.click
        expect(progress_input.value).to eq('0')
      end
    end
  end

  shared_examples 'work items health status' do
    let(:dropdown_selector) { '[data-testid="work-item-health-status-dropdown"]' }

    it 'successfully sets health status' do
      expect(find(dropdown_selector)).to have_content 'None'

      page.find(dropdown_selector).click
      find_by_testid('listbox-item-needsAttention').click

      wait_for_requests

      expect(find(dropdown_selector)).to have_content 'Needs attention'
      expect(work_item.reload.health_status).to eq('needs_attention')
    end
  end

  describe 'creating objective from issues list' do
    before do
      visit project_issues_path(project)
    end

    it 'creates an objective from the "New issue" toggle button' do
      click_button _('Issue type')
      click_button s_('OKR|New objective')
      send_keys 'I object!'
      click_button 'Create objective'

      expect(page).to have_link 'I object!'
    end
  end

  context 'for objective' do
    let(:work_item) { objective }
    let(:work_items_path) { project_work_item_path(project, objective.iid) }

    before do
      visit work_items_path
    end

    it 'assigns to multiple users' do
      find_by_testid('work-item-assignees-input').fill_in(with: user.username)
      wait_for_requests

      send_keys(:enter)
      find("body").click
      wait_for_requests

      find_by_testid('work-item-assignees-input').fill_in(with: user2.username)
      wait_for_requests

      send_keys(:enter)
      find("body").click
      wait_for_requests

      expect(work_item.reload.assignees).to include(user)
      expect(work_item.reload.assignees).to include(user2)
    end

    it_behaves_like 'work items toggle status button'
    it_behaves_like 'work items assignees'
    it_behaves_like 'work items labels'
    it_behaves_like 'work items progress'
    it_behaves_like 'work items health status'
    it_behaves_like 'work items comments', :objective
    it_behaves_like 'work items description'
    it_behaves_like 'work items todos'
    it_behaves_like 'work items award emoji'
    it_behaves_like 'work items parent', :objective

    context 'in hierarchy' do
      it 'shows no children', :aggregate_failures do
        within_testid('work-item-tree') do
          expect(page).to have_content('Child objectives and key results')
          expect(page).to have_content('No objectives or key results are currently assigned.')
        end
      end

      it 'toggles widget body', :aggregate_failures do
        within_testid('work-item-tree') do
          expect(page).to have_selector('[data-testid="work-item-tree"] [data-testid="widget-body"]')

          click_button 'Collapse'

          expect(page).not_to have_selector('[data-testid="work-item-tree"] [data-testid="widget-body"]')

          click_button 'Expand'

          expect(page).to have_selector('[data-testid="work-item-tree"] [data-testid="widget-body"]')
        end
      end

      it 'toggles forms', :aggregate_failures do
        within_testid('work-item-tree') do
          expect(page).not_to have_selector('[data-testid="add-tree-form"]')

          click_button 'Add'
          click_button 'New objective'

          expect(page).to have_selector('[data-testid="add-tree-form"]')
          expect(find_by_testid('add-tree-form')).to have_button('Create objective', disabled: true)

          click_button 'Add'
          click_button 'Existing objective'

          expect(find_by_testid('add-tree-form')).to have_button('Add objective', disabled: true)

          click_button 'Add'
          click_button 'New key result'

          expect(find_by_testid('add-tree-form')).to have_button('Create key result', disabled: true)

          click_button 'Add'
          click_button 'Existing key result'

          expect(find_by_testid('add-tree-form')).to have_button('Add key result', disabled: true)

          click_button 'Cancel'

          expect(page).not_to have_selector('[data-testid="add-tree-form"]')
        end
      end
    end

    context 'in child metadata' do
      it 'displays progress of 0% by default, in tree and modal' do
        create_okr('objective', 'Objective 2')

        within_testid('work-item-tree') do
          expect(page).to have_content('Objective 2')
          expect(page).to have_content('0%')

          click_link 'Objective 2'
        end

        wait_for_all_requests

        within_testid('work-item-detail-modal') do
          expect(page).to have_content('0%')
        end
      end
    end

    it 'adds existing child item with proper link', :aggregate_failures do
      within_testid('work-item-tree') do
        click_button 'Add'
        click_button 'Existing objective'

        find_by_testid('work-item-token-select-input').set(child_objective.title)

        wait_for_all_requests
        click_button child_objective.title

        send_keys :escape

        click_button('Add objective')

        wait_for_all_requests

        child_objective_link = find('[data-testid="links-child"] a.gl-link')

        # Only part of the link is checked which is group/project/work-items/-/iid
        expect(child_objective_link['href']).to have_content(project_work_item_path(project, child_objective.iid))
      end
    end

    it 'creates objective' do
      create_okr('objective', 'Objective 2')

      expect(find_by_testid('work-item-tree')).to have_content('Objective 2')
    end

    it 'removes direct child of objective with undoing' do
      create_okr('objective', 'Objective 2')

      find_by_testid('links-child').hover
      within_testid('links-child') do
        find_by_testid('remove-work-item-link').click
        wait_for_all_requests
      end

      within_testid('work-item-tree') do
        expect(page).not_to have_content('Objective 2')
      end

      page.within('.gl-toast') do
        expect(find('.toast-body')).to have_content(_('Child removed'))
        find('.b-toaster a', text: 'Undo').click
      end

      wait_for_all_requests

      within_testid('work-item-tree') do
        expect(page).to have_content('Objective 2')
      end
    end

    it 'removes indirect child of objective with undoing' do
      create_okr('objective', 'Objective 2')

      within_testid('work-item-tree') do
        click_link 'Objective 2'

        wait_for_all_requests
      end

      within_testid('work-item-detail-modal') do
        create_okr('objective', 'Child objective 1')
        expect(page).to have_content('Child objective 1')

        click_button 'Close'
      end

      visit work_items_path
      wait_for_all_requests

      within_testid('work-item-tree') do
        within_testid('widget-body') do
          click_button 'Expand'

          wait_for_all_requests

          expect(page).to have_content('Child objective 1')
        end
      end

      within_testid('tree-children') do
        find_by_testid('links-child').hover
        find_by_testid('remove-work-item-link').click

        wait_for_all_requests

        expect(page).not_to have_content('Child objective 1')
      end

      page.within('.gl-toast') do
        expect(find('.toast-body')).to have_content(_('Child removed'))
        find('.b-toaster a', text: 'Undo').click
      end

      wait_for_all_requests

      within_testid('work-item-tree') do
        expect(page).to have_content('Child objective 1')
      end
    end

    it 'creates key result' do
      create_okr('key result', 'KR 2')

      expect(find_by_testid('work-item-tree')).to have_content('KR 2')
    end

    it 'reorders children', :aggregate_failures do
      create_okr('key result', 'KR 1')
      create_okr('key result', 'KR 2')
      create_okr('key result', 'KR 3')
      click_button 'Cancel'

      expect(page).to have_css('.tree-item:nth-child(1) .item-title', text: 'KR 1')
      expect(page).to have_css('.tree-item:nth-child(2) .item-title', text: 'KR 2')
      expect(page).to have_css('.tree-item:nth-child(3) .item-title', text: 'KR 3')

      drag_to(selector: '.sortable-container', from_index: 0, to_index: 2)

      expect(page).to have_css('.tree-item:nth-child(1) .item-title', text: 'KR 2')
      expect(page).to have_css('.tree-item:nth-child(2) .item-title', text: 'KR 3')
      expect(page).to have_css('.tree-item:nth-child(3) .item-title', text: 'KR 1')
    end
  end

  context 'for keyresult' do
    let(:work_item) { key_result }
    let(:work_items_path) { project_work_item_path(project, key_result.iid) }

    before do
      visit work_items_path
    end

    it 'assigns to multiple users' do
      find_by_testid('work-item-assignees-input').fill_in(with: user.username)
      wait_for_requests

      send_keys(:enter)
      find("body").click
      wait_for_requests

      find_by_testid('work-item-assignees-input').fill_in(with: user2.username)
      wait_for_requests

      send_keys(:enter)
      find("body").click
      wait_for_requests

      expect(work_item.reload.assignees).to include(user)
      expect(work_item.reload.assignees).to include(user2)
    end

    it_behaves_like 'work items toggle status button'
    it_behaves_like 'work items assignees'
    it_behaves_like 'work items labels'
    it_behaves_like 'work items progress'
    it_behaves_like 'work items health status'
    it_behaves_like 'work items comments', :key_result
    it_behaves_like 'work items description'
    it_behaves_like 'work items parent', :objective
  end

  context 'for guest users' do
    before do
      project.add_guest(user)

      sign_in(user)

      stub_licensed_features(okrs: true, issuable_health_status: true)
      stub_feature_flags(work_items: true, okrs_mvc: true)

      visit project_work_item_path(project, objective.iid)
    end

    it_behaves_like 'work items todos'
  end

  def create_okr(type, title)
    wait_for_all_requests

    within_testid('work-item-tree') do
      click_button 'Add'
      click_button "New #{type}"
      wait_for_all_requests # wait for work items type to load

      fill_in 'Add a title', with: title

      click_button "Create #{type}"

      wait_for_all_requests
    end
  end
end
