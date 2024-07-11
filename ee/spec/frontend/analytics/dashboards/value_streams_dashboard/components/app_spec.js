import { GlAlert, GlLink, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import {
  DASHBOARD_TITLE,
  DASHBOARD_DESCRIPTION,
  DASHBOARD_DOCS_LINK,
  DASHBOARD_SURVEY_LINK,
} from 'ee/analytics/dashboards/constants';
import * as yamlConfigUtils from 'ee/analytics/dashboards/yaml_utils';
import Component from 'ee/analytics/dashboards/value_streams_dashboard/components/app.vue';
import DoraVisualization from 'ee/analytics/dashboards/components/dora_visualization.vue';
import DoraPerformersScore from 'ee/analytics/dashboards/components/dora_performers_score.vue';

describe('Executive dashboard app', () => {
  let wrapper;
  let userCalloutDismissSpy;
  const fullPath = 'groupFullPath';
  const testPaths = ['group', 'group/a', 'group/b', 'group/c', 'group/d', 'group/e'];
  const testPanels = testPaths.map((namespace) => ({ data: { namespace } }));

  const createWrapper = async ({ props = {}, shouldShowCallout = true } = {}) => {
    userCalloutDismissSpy = jest.fn();

    wrapper = shallowMountExtended(Component, {
      propsData: {
        fullPath,
        ...props,
      },
      stubs: {
        GlSprintf,
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
      },
    });

    await waitForPromises();
  };

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findByTestId('alert-error');
  const findTitle = () => wrapper.findByTestId('dashboard-title');
  const findDescription = () => wrapper.findByTestId('dashboard-description');
  const findDoraVisualizations = () => wrapper.findAllComponents(DoraVisualization);
  const findDoraPerformersScorePanels = () => wrapper.findAllComponents(DoraPerformersScore);
  const findAlertBanner = () => wrapper.findByTestId('alert-banner');
  const findAlertBannerText = () => findAlertBanner().findComponent(GlSprintf).text();
  const findAlertBannerLink = () => findAlertBanner().findComponent(GlLink);

  it('shows a loading skeleton when fetching the YAML config', () => {
    createWrapper();
    expect(findSkeletonLoader().exists()).toBe(true);
  });

  describe('default config', () => {
    it('renders the page title', async () => {
      await createWrapper();
      expect(findTitle().text()).toBe(DASHBOARD_TITLE);
    });

    it('renders the description', async () => {
      await createWrapper();
      expect(findDescription().text()).toContain(DASHBOARD_DESCRIPTION);
      expect(findDescription().findComponent(GlLink).attributes('href')).toBe(DASHBOARD_DOCS_LINK);
    });

    it('renders a visualization for the group fullPath', async () => {
      await createWrapper();
      const charts = findDoraVisualizations();
      expect(charts.length).toBe(1);

      const [chart] = charts.wrappers;
      expect(chart.props()).toMatchObject({ data: { namespace: fullPath } });
    });

    it('queryPaths are shown in addition to the group visualization', async () => {
      const queryPaths = [
        { namespace: 'group/one', isProject: false },
        { namespace: 'group/two', isProject: false },
        { namespace: 'group/three', isProject: false },
      ];
      const groupFullPath = { namespace: fullPath };
      await createWrapper({ props: { queryPaths } });

      const charts = findDoraVisualizations();
      expect(charts.length).toBe(4);

      [groupFullPath, ...queryPaths].forEach(({ namespace }, index) => {
        expect(charts.wrappers[index].props()).toMatchObject({ data: { namespace } });
      });
    });

    it('does not render group-only visualizations for project queryPaths', async () => {
      const groupQueryPaths = [
        { namespace: 'group/one', isProject: false },
        { namespace: 'group/two', isProject: false },
      ];
      const projectQueryPath = { namespace: 'project/one', isProject: true };
      const groupFullPath = { namespace: fullPath };
      const queryPaths = [projectQueryPath, ...groupQueryPaths];

      await createWrapper({ props: { queryPaths } });

      const panels = findDoraPerformersScorePanels();
      expect(panels).toHaveLength(groupQueryPaths.length + 1);

      [groupFullPath, ...groupQueryPaths].forEach(({ namespace }, index) => {
        expect(panels.wrappers[index].props()).toMatchObject({ data: { namespace } });
      });
    });
  });

  describe('YAML config', () => {
    const yamlConfigProject = { id: 3, fullPath: 'group/project' };
    const panels = [
      { title: 'One', data: { namespace: 'group/one' } },
      { data: { namespace: 'group/two' } },
    ];

    it('falls back to the default config with an alert if it fails to fetch', async () => {
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue(null);
      await createWrapper({ props: { yamlConfigProject } });
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe('Failed to load YAML config from Project: group/project');
    });

    it('renders a custom page title', async () => {
      const title = 'TEST TITLE';
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ title });
      await createWrapper({ props: { yamlConfigProject } });
      expect(findTitle().text()).toBe(title);
    });

    it('renders a custom description', async () => {
      const description = 'TEST DESCRIPTION';
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ description });
      await createWrapper({ props: { yamlConfigProject } });
      expect(findDescription().text()).toBe(description);
      expect(findDescription().findComponent(GlLink).exists()).toBe(false);
    });

    it('renders a visualization for each panel', async () => {
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ panels });
      await createWrapper({ props: { yamlConfigProject } });

      const charts = findDoraVisualizations();
      expect(charts.length).toBe(2);

      expect(charts.wrappers[0].props()).toMatchObject(panels[0]);
      expect(charts.wrappers[1].props()).toMatchObject(panels[1]);
    });

    it('can render any number of visualizations', async () => {
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ panels: testPanels });
      await createWrapper({ props: { yamlConfigProject } });

      const charts = findDoraVisualizations();
      expect(charts.length).toBe(6);
    });

    it('queryPaths override the panels list', async () => {
      const queryPaths = [
        { namespace: 'group/one', isProject: false },
        { namespace: 'group/two', isProject: false },
        { namespace: 'group/three', isProject: false },
      ];
      const groupFullPath = { namespace: fullPath };

      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ panels });
      await createWrapper({ props: { yamlConfigProject, queryPaths } });

      const charts = findDoraVisualizations();
      expect(charts.length).toBe(4);

      [groupFullPath, ...queryPaths].forEach(({ namespace }, index) => {
        expect(charts.wrappers[index].props()).toMatchObject({ data: { namespace } });
      });
    });
  });

  describe('VSD feedback banner', () => {
    it('displays the alert banner correctly', () => {
      createWrapper();

      expect(findAlertBannerText()).toBe(
        'To help us improve the Value Stream Management Dashboard, please share feedback about your experience in this',
      );

      const alertBannerLink = findAlertBannerLink();

      expect(alertBannerLink.text()).toBe('survey');
      expect(alertBannerLink.attributes('href')).toBe(DASHBOARD_SURVEY_LINK);
    });

    it('dismisses the callout when closed', () => {
      createWrapper();

      findAlertBanner().findComponent(GlAlert).vm.$emit('dismiss');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });

    it('is not displayed once it has been dismissed', () => {
      createWrapper({ shouldShowCallout: false });

      expect(findAlertBanner().exists()).toBe(false);
    });
  });
});
