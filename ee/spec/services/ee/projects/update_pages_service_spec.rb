# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdatePagesService, feature_category: :pages do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:build) { create_pages_build_and_artifacts(project) }

  subject(:service) { described_class.new(project, build) }

  before do
    stub_pages_setting(enabled: true)
  end

  context 'when pages_multiple_versions is not enabled for project' do
    it 'does not save the given path prefix' do
      expect(::Gitlab::Pages)
        .to receive(:multiple_versions_enabled_for?)
        .with(build.project)
        .and_return(false)

      expect do
        expect(service.execute[:status]).to eq(:success)
      end.to change { project.pages_deployments.count }.by(1)

      deployment = project.pages_deployments.last

      expect(deployment.path_prefix).to be_nil
    end
  end

  context 'when pages_multiple_versions is enabled for project', :aggregate_failures do
    before do
      allow(::Gitlab::Pages)
        .to receive(:multiple_versions_enabled_for?)
        .with(build.project)
        .and_return(true)
        .twice # it's called from within the build.pages.path_prefix as well
    end

    it 'succeeds and create a new PagesDeployment' do
      expect do
        expect(service.execute[:status]).to eq(:success)
      end.to change { project.pages_deployments.count }.by(1)
    end

    it 'saves the given path prefix' do
      service.execute

      expect(project.pages_deployments.last.path_prefix).to eq('__pages__prefix__')
    end

    it 'URL escapes the path prefix value' do
      allow(build).to receive(:pages).and_return({ path_prefix: '!' })

      service.execute

      expect(project.pages_deployments.last.path_prefix).to eq('%21')
    end
  end

  def create_pages_build_and_artifacts(project)
    build = create(
      :ci_build,
      name: 'pages',
      pipeline: create(:ci_pipeline, project: project, sha: project.commit('HEAD').sha),
      ref: 'HEAD',
      options: {
        pages: {
          path_prefix: '__pages__prefix__'
        }
      })

    create(
      :ci_job_artifact,
      :correct_checksum,
      file: fixture_file_upload('spec/fixtures/pages.zip'),
      job: build)

    create(
      :ci_job_artifact,
      file_type: :metadata,
      file_format: :gzip,
      file: fixture_file_upload('spec/fixtures/pages.zip.meta'),
      job: build)

    build.reload
  end
end
