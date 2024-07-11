# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Epic
          class New < QA::Page::Base
            view 'ee/app/assets/javascripts/epic/components/epic_form.vue' do
              element 'confidential-epic-checkbox'
              element 'create-epic-button'
              element 'epic-title-field', required: true
            end

            def create_new_epic
              click_element('create-epic-button', EE::Page::Group::Epic::Show)
            end

            def enable_confidential_epic
              check_element('confidential-epic-checkbox', true)
            end

            def set_title(title)
              fill_element('epic-title-field', title)
            end
          end
        end
      end
    end
  end
end
