# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Geo::ProjectsController, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:geo_node) { create(:geo_node, :primary) }

  before do
    sign_in(admin)
  end

  shared_examples 'license required' do
    context 'without a valid license' do
      it 'redirects to 403 page' do
        expect(subject).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe '#index' do
    subject { get :index }

    it_behaves_like 'license required'

    context 'with a valid license' do
      render_views

      before do
        stub_licensed_features(geo: true)
        stub_current_geo_node(geo_node)
      end

      shared_examples 'redirects /admin/geo/replication/projects' do
        it do
          get :index

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(
            "/admin/geo/sites/#{geo_node.id}/replication/project_repositories"
          )
        end
      end

      context 'on primary' do
        before do
          stub_primary_node
        end

        it_behaves_like 'redirects /admin/geo/replication/projects'
      end

      context 'on secondary' do
        before do
          stub_secondary_node
        end

        it_behaves_like 'redirects /admin/geo/replication/projects'
      end
    end
  end
end
