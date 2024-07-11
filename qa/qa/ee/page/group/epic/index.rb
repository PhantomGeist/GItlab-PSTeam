# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Epic
          class Index < QA::Page::Base
            view 'app/assets/javascripts/vue_shared/issuable/list/components/issuable_item.vue' do
              element 'issuable-title-link'
            end

            view 'ee/app/assets/javascripts/epics_list/components/epics_list_root.vue' do
              element 'new-epic-button'
            end

            def click_new_epic
              click_element('new-epic-button', EE::Page::Group::Epic::New)
            end

            def click_first_epic(page = nil)
              all_elements('issuable-title-link', minimum: 1).first.click
              page.validate_elements_present! if page
            end

            def has_epic_title?(title)
              wait_until do
                has_element?('issuable-title-link', text: title)
              end
            end
          end
        end
      end
    end
  end
end
