# frozen_string_literal: true

module API
  class DependencyListExports < ::API::Base
    feature_category :dependency_management
    urgency :low

    before do
      authenticate!
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      params do
        requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
      end
      desc 'Generate a dependency list export on a project-level'
      post ':id/dependency_list_exports' do
        authorize! :read_dependency, user_project

        dependency_list_export = ::Dependencies::CreateExportService.new(user_project, current_user).execute

        present dependency_list_export, with: EE::API::Entities::DependencyListExport
      end
    end

    resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      params do
        requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'
      end
      desc 'Generate a dependency list export on a group-level'
      post ':id/dependency_list_exports' do
        authorize! :read_dependency, user_group

        dependency_list_export = ::Dependencies::CreateExportService.new(user_group, current_user).execute

        present dependency_list_export, with: EE::API::Entities::DependencyListExport
      end
    end

    resource :pipelines do
      params do
        requires :id, types: [String, Integer], desc: 'The ID of the pipeline'

        optional :export_type, type: String, values: %w[sbom dependency_list], desc: 'The type of the export file'
      end
      desc 'Generate a dependency list export on a pipeline-level'
      post ':id/dependency_list_exports' do
        not_found! unless Feature.enabled?(:merge_sbom_api, user_pipeline&.project)

        # Currently, we only support sbom export type for this endpoint.
        not_found! if params[:export_type] != 'sbom'

        authorize! :read_dependency, user_pipeline

        dependency_list_export = ::Dependencies::CreateExportService.new(
          user_pipeline, current_user, params[:export_type]).execute

        present dependency_list_export, with: EE::API::Entities::DependencyListExport
      end
    end

    params do
      requires :export_id, types: [Integer, String], desc: 'The ID of the dependency list export'
    end
    desc 'Get a dependency list export'
    get 'dependency_list_exports/:export_id' do
      dependency_list_export = ::Dependencies::FetchExportService
      .new(params[:export_id].to_i).execute

      authorize! :read_dependency_list_export, dependency_list_export

      if dependency_list_export&.finished?
        present dependency_list_export, with: EE::API::Entities::DependencyListExport
      else
        ::Gitlab::PollingInterval.set_api_header(self, interval: 5_000)
        status :accepted
      end
    end

    desc 'Download a dependency list export'
    get 'dependency_list_exports/:export_id/download' do
      dependency_list_export = ::Dependencies::FetchExportService
      .new(params[:export_id].to_i).execute

      authorize! :read_dependency_list_export, dependency_list_export

      if dependency_list_export&.finished?
        present_carrierwave_file!(dependency_list_export.file)
      else
        not_found!('DependencyListExport')
      end
    end
  end
end
