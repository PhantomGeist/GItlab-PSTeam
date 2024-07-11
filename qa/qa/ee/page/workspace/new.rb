# frozen_string_literal: true

module QA
  module EE
    module Page
      module Workspace
        class New < QA::Page::Base
          include QA::Page::Component::Dropdown
          view 'ee/app/assets/javascripts/remote_development/pages/create.vue' do
            element :workspace_devfile_project_id_field
            element :workspace_cluster_agent_id_field
            element :save_workspace_button
          end

          def select_devfile_project(project)
            click_element(:workspace_devfile_project_id_field)
            search_and_select(project)
          end

          def select_cluster_agent(agent)
            agent_selector = find_element(:workspace_cluster_agent_id_field)
            options = agent_selector.all('option')

            raise "No agent available" if options.empty?

            agent_selector.select agent
          end

          def save_workspace
            click_element(:save_workspace_button, skip_finished_loading_check: true)
          end
        end
      end
    end
  end
end
