# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group navbar', :js, feature_category: :groups_and_projects do
  include NavbarStructureHelper
  include WaitForRequests
  include WikiHelpers

  include_context 'group navbar structure'

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  context 'for maintainers' do
    before do
      group.add_maintainer(user)
      stub_group_wikis(false)
      sign_in(user)

      create_package_nav(_('Operate'))
      insert_after_nav_item(_('Analyze'), new_nav_item: settings_for_maintainer_nav_item)
    end

    context 'when devops adoption analytics is available' do
      before do
        stub_licensed_features(group_level_devops_adoption: true)

        insert_after_sub_nav_item(
          _('Contribution analytics'),
          within: _('Analyze'),
          new_sub_nav_item_name: _('DevOps adoption')
        )

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when productivity analytics is available' do
      before do
        stub_licensed_features(productivity_analytics: true)

        insert_after_sub_nav_item(
          _('Contribution analytics'),
          within: _('Analyze'),
          new_sub_nav_item_name: _('Productivity analytics')
        )

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when value stream analytics is available' do
      before do
        stub_licensed_features(cycle_analytics_for_groups: true)

        insert_before_sub_nav_item(
          _('Contribution analytics'),
          within: _('Analyze'),
          new_sub_nav_item_name: _('Value stream analytics')
        )

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when epics are available' do
      before do
        stub_licensed_features(epics: true)

        insert_after_sub_nav_item(
          _('Issues'),
          within: _('Plan'),
          new_sub_nav_item_name: _('Epics')
        )
        insert_after_sub_nav_item(
          _('Issue board'),
          within: _('Plan'),
          new_sub_nav_item_name: _('Epic boards')
        )
        insert_after_sub_nav_item(
          _('Epic boards'),
          within: _('Plan'),
          new_sub_nav_item_name: _('Roadmap')
        )

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when packages are available' do
      before do
        stub_config(packages: { enabled: true }, registry: { enabled: false })

        visit group_path(group)
      end

      context 'when container registry is available' do
        before do
          stub_config(registry: { enabled: true })

          insert_after_sub_nav_item(
            _('Package Registry'),
            within: _('Deploy'),
            new_sub_nav_item_name: _('Container Registry')
          )

          visit group_path(group)
        end

        it_behaves_like 'verified navigation bar'
      end

      context 'when customer relations feature is enabled' do
        let(:group) { create(:group, :crm_enabled) }

        before do
          insert_customer_relations_nav(_('Iterations'))

          visit group_path(group)
        end

        it_behaves_like 'verified navigation bar'
      end

      context 'when customer relations feature enabled but subgroup' do
        let(:group) { create(:group, :crm_enabled, parent: create(:group)) }

        before do
          visit group_path(group)
        end

        it_behaves_like 'verified navigation bar'
      end
    end

    context 'when iterations are available' do
      before do
        stub_licensed_features(iterations: true)

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when group wiki is available' do
      before do
        stub_group_wikis(true)

        insert_after_sub_nav_item(
          _('Iterations'),
          within: _('Plan'),
          new_sub_nav_item_name: _('Wiki')
        )
        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when harbor registry is available' do
      let(:harbor_integration) { create(:harbor_integration, group: group, project: nil) }

      before do
        group.update!(harbor_integration: harbor_integration)

        insert_harbor_registry_nav(_('Kubernetes'))

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end
  end

  context 'for owners', :saas do
    before do
      group.add_owner(user)
      stub_group_wikis(false)
      stub_licensed_features(domain_verification: true)
      sign_in(user)
      create_package_nav(_('Operate'))
    end

    describe 'structure' do
      before do
        insert_after_nav_item(_('Analyze'), new_nav_item: settings_nav_item)

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when SAML SSO is available' do
      before do
        stub_licensed_features(group_saml: true, domain_verification: true)

        insert_after_nav_item(_('Analyze'), new_nav_item: settings_nav_item)
        insert_after_sub_nav_item(
          s_('UsageQuota|Usage Quotas'),
          within: _('Settings'),
          new_sub_nav_item_name: _('SAML SSO')
        )

        visit group_path(group)
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
            _('Dependency list'),
            _('Audit events'),
            _('Compliance center')
          ]
        }
      end

      before do
        stub_licensed_features(
          security_dashboard: true,
          group_level_compliance_dashboard: true,
          domain_verification: true
        )

        insert_after_nav_item(_('Analyze'), new_nav_item: settings_nav_item)

        visit group_path(group)
      end

      it_behaves_like 'verified navigation bar'
    end
  end
end
