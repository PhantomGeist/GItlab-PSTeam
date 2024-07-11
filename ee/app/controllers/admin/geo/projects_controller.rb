# frozen_string_literal: true

module Admin
  module Geo
    class ProjectsController < Admin::Geo::ApplicationController
      before_action :check_license!
      before_action :limited_actions_message!
      before_action :load_node_data, only: [:index]

      def index
        redirect_to admin_geo_nodes_path unless @current_node
        redirect_to project_repositories_path
      end

      private

      def project_repositories_path
        "/admin/geo/sites/#{@current_node.id}/replication/project_repositories"
      end
    end
  end
end
