# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project navbar', :js, feature_category: :navigation do
  include NavbarStructureHelper

  include_context 'project navbar structure'

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, namespace: user.namespace) }

  before do
    project.add_owner(user)

    sign_in(user)

    stub_config(registry: { enabled: false })
    stub_feature_flags(ml_experiment_tracking: false)
    stub_feature_flags(remove_monitor_metrics: false)
    insert_package_nav
    insert_infrastructure_registry_nav
    insert_infrastructure_google_cloud_nav
    insert_infrastructure_aws_nav
  end

  context 'when iterations is available' do
    before do
      stub_licensed_features(iterations: true)
    end

    context 'when project is namespaced to a user' do
      before do
        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when project is namespaced to a group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :repository, group: group) }

      before do
        group.add_developer(user)

        insert_after_sub_nav_item(
          _('Milestones'),
          within: _('Plan'),
          new_sub_nav_item_name: _('Iterations')
        )

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end
  end

  context 'when issue analytics is available' do
    before do
      stub_licensed_features(issues_analytics: true)

      insert_after_sub_nav_item(
        _('Merge request analytics'),
        within: _('Analyze'),
        new_sub_nav_item_name: _('Issue analytics')
      )

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when security dashboard is available' do
    let(:secure_nav_item) do
      {
        nav_item: _('Secure'),
        nav_sub_items: [
          _('Security dashboard'),
          _('Vulnerability report'),
          _('Audit events'),
          s_('OnDemandScans|On-demand scans'),
          _('Security configuration')
        ]
      }
    end

    before do
      stub_licensed_features(security_dashboard: true, security_on_demand_scans: true)

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'

    context 'when FIPS mode is enabled' do
      let(:secure_nav_item) do
        {
          nav_item: _('Secure'),
          nav_sub_items: [
            _('Security dashboard'),
            _('Vulnerability report'),
            _('Audit events'),
            _('Security configuration')
          ]
        }
      end

      before do
        # When the Javascript driver is enabled ::Gitlab::FIPS.enabled? is called a 4th time
        allow(::Gitlab::FIPS).to receive(:enabled?).exactly(4).times.and_return(true)
        stub_licensed_features(security_dashboard: true, security_on_demand_scans: true)

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end
  end

  context 'when packages are available' do
    before do
      stub_config(packages: { enabled: true }, registry: { enabled: false })

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when container registry is available' do
    before do
      stub_config(packages: { enabled: true }, registry: { enabled: true })

      insert_container_nav

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when harbor registry is available' do
    let(:harbor_integration) { create(:harbor_integration) }

    before do
      project.update!(harbor_integration: harbor_integration)

      insert_harbor_registry_nav(_('AWS'))

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when analytics dashboards is available' do
    before do
      stub_feature_flags(combined_analytics_dashboards: true)
      stub_licensed_features(combined_project_analytics_dashboards: true)

      insert_before_sub_nav_item(
        _('Value stream analytics'),
        within: _('Analyze'),
        new_sub_nav_item_name: _('Analytics dashboards')
      )

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when model experiments is available' do
    before do
      stub_feature_flags(ml_experiment_tracking: true)

      insert_model_experiments_nav(_('Merge request analytics'))

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end
end
