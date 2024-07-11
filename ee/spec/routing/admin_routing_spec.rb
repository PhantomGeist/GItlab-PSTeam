# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'EE-specific admin routing' do
  describe Admin::Geo::ProjectsController, 'routing' do
    it 'routes / to #index' do
      expect(get('/admin/geo/replication/projects')).to route_to('admin/geo/projects#index')
    end
  end

  describe Admin::Geo::DesignsController, 'routing' do
    it 'routes / to #index' do
      expect(get('/admin/geo/replication/designs')).to route_to('admin/geo/designs#index')
    end
  end

  describe Admin::Geo::ReplicablesController, 'routing' do
    Gitlab::Geo.enabled_replicator_classes.map(&:replicable_name_plural).each do |replicable_name_plural|
      it "routes /admin/geo/replication/#{replicable_name_plural} to replicables#index" do
        expect(get("/admin/geo/replication/#{replicable_name_plural}")).to route_to('admin/geo/replicables#index', replicable_name_plural: replicable_name_plural)
      end
    end
  end

  describe Admin::Geo::NodesController, 'routing' do
    let(:geo_node) { create(:geo_node) }

    it 'routes / to #index' do
      expect(get('/admin/geo')).to route_to('admin/geo/nodes#index')
    end

    it 'routes /sites to #index' do
      expect(get('/admin/geo/sites')).to route_to('admin/geo/nodes#index')
    end

    it 'routes /new to #new' do
      expect(get('/admin/geo/sites/new')).to route_to('admin/geo/nodes#new')
    end

    it 'routes /edit to #edit' do
      expect(get("/admin/geo/sites/#{geo_node.id}/edit")).to route_to('admin/geo/nodes#edit', id: geo_node.to_param)
    end

    it 'routes post / to #create' do
      expect(post('/admin/geo/sites/')).to route_to('admin/geo/nodes#create')
    end

    it 'routes patch /:id to #update' do
      expect(patch("/admin/geo/sites/#{geo_node.id}")).to route_to('admin/geo/nodes#update', id: geo_node.to_param)
    end
  end

  describe Admin::Geo::SettingsController, 'routing' do
    it 'routes / to #show' do
      expect(get('/admin/geo/settings')).to route_to('admin/geo/settings#show')
    end

    it 'routes patch / to #update' do
      expect(patch('/admin/geo/settings')).to route_to('admin/geo/settings#update')
    end
  end

  describe Admin::EmailsController, 'routing' do
    it 'routes to #show' do
      expect(get('/admin/email')).to route_to('admin/emails#show')
    end

    it 'routes to #create' do
      expect(post('/admin/email')).to route_to('admin/emails#create')
    end
  end

  describe Admin::ApplicationSettingsController, 'routing' do
    it 'redirects #geo to #geo_redirection' do
      expect(get('/admin/application_settings/geo')).to route_to('admin/geo/settings#show')
    end

    it 'routes to #templates' do
      expect(get('/admin/application_settings/templates')).to route_to('admin/application_settings#templates')
      expect(patch('/admin/application_settings/templates')).to route_to('admin/application_settings#templates')
    end

    it 'redirects /advanced_search to to #advanced_search' do
      expect(get('/admin/application_settings/advanced_search')).to route_to('admin/application_settings#advanced_search')
      expect(patch('/admin/application_settings/advanced_search')).to route_to('admin/application_settings#advanced_search')
    end
  end

  describe Admin::ApplicationSettings::RolesAndPermissionsController, 'routing' do
    it 'routes to the new member role' do
      expect(get('/admin/application_settings/roles_and_permissions/new')).to route_to('admin/application_settings/roles_and_permissions#index', vueroute: 'new')
    end
  end
end
