# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Epic
          class Show < QA::Page::Base
            include QA::Page::Component::Issuable::Common
            include QA::Page::Component::Note

            view 'ee/app/assets/javascripts/epic/components/epic_header_actions.vue' do
              element 'desktop-dropdown'
              element 'toggle-status-button'
            end

            view 'ee/app/assets/javascripts/related_items_tree/components/epic_issue_actions_split_button.vue' do
              element 'epic-issue-actions-split-button'
            end

            view 'ee/app/assets/javascripts/related_items_tree/components/tree_item.vue' do
              element 'related-issue-item'
            end

            view 'ee/app/assets/javascripts/related_items_tree/components/tree_item_body.vue' do
              element 'remove-issue-button'
            end

            def add_issue_to_epic(issue_url)
              click_element('epic-issue-actions-split-button')
              find('button', text: 'Add an existing issue').click
              fill_element('add-issue-field', issue_url)
              # Clicking the title blurs the input
              click_element('issue-title')
              click_element('add-issue-button')
            end

            def remove_issue_from_epic
              click_element('remove-issue-button')
              # Capybara code is used below due to the modal being defined in the @gitlab/ui project
              find('#item-remove-confirmation___BV_modal_footer_ .btn-danger').click
            end

            def close_epic
              open_actions_dropdown
              click_element('toggle-status-button', text: 'Close epic')
            end

            def reopen_epic
              open_actions_dropdown
              click_element('toggle-status-button', text: 'Reopen epic')
            end

            def has_related_issue_item?
              has_element?('related-issue-item')
            end

            def has_no_related_issue_item?
              has_no_element?('related-issue-item')
            end

            def open_actions_dropdown
              # We use find here because these are gitlab-ui elements
              find('[data-testid="desktop-dropdown"] > button').click
            end
          end
        end
      end
    end
  end
end
