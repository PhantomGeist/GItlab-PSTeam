import { GlLoadingIcon } from '@gitlab/ui';
import { GlLineChart } from '@gitlab/ui/dist/charts';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import SecurityTrainingPromoBanner from 'ee/security_dashboard/components/project/security_training_promo_banner.vue';
import ProjectSecurityDashboard from 'ee/security_dashboard/components/project/project_security_dashboard.vue';
import projectsHistoryQuery from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_by_day_and_count.query.graphql';
import severitiesCountQuery from 'ee/security_dashboard/graphql/queries/vulnerability_severities_count.query.graphql';
import { useFakeDate } from 'helpers/fake_date';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockProjectSecurityChartsWithData, mockSeverityCountsWithData } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/icon_utils', () => ({
  getSvgIconPathContent: jest.fn().mockResolvedValue('mockSvgPathContent'),
}));

describe('Project Security Dashboard component', () => {
  let wrapper;

  const projectFullPath = 'project/path';

  const findLineChart = () => wrapper.findComponent(GlLineChart);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findSecurityTrainingPromoBanner = () => wrapper.findComponent(SecurityTrainingPromoBanner);

  const createApolloProvider = (...queries) => {
    return createMockApollo([...queries]);
  };

  const createWrapper = ({ historyQueryData, severitiesCountQueryData } = {}) => {
    wrapper = shallowMount(ProjectSecurityDashboard, {
      apolloProvider: createApolloProvider(
        [projectsHistoryQuery, jest.fn().mockResolvedValue(historyQueryData)],
        [severitiesCountQuery, jest.fn().mockResolvedValue(severitiesCountQueryData)],
      ),
      propsData: { projectFullPath },
    });
  };

  describe('when query is loading', () => {
    it('should only show the loading icon', () => {
      createWrapper();

      expect(findLineChart().exists()).toBe(false);
      expect(findSecurityTrainingPromoBanner().exists()).toBe(false);
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when there is history data', () => {
    useFakeDate(2021, 3, 11);
    const todayIso = '2021-04-11';

    beforeEach(async () => {
      createWrapper({
        historyQueryData: mockProjectSecurityChartsWithData(),
        severitiesCountQueryData: mockSeverityCountsWithData(),
      });
      await waitForPromises();
    });

    it('should display the chart with data', () => {
      expect(findLineChart().props('data')).toMatchSnapshot();
    });

    it.each(['critical', 'high', 'medium', 'info', 'unknown'])(
      'should use the up-to-date vulnerability count for the latest date for "%s" severity findings',
      (severity) => {
        const series = findLineChart()
          .props('data')
          .find(({ key }) => key === severity);
        const trendingData = mockProjectSecurityChartsWithData().data.project
          .vulnerabilitiesCountByDay.nodes;

        const todaysTrendingSeverityCount = trendingData.find(({ date }) => date === todayIso)[
          severity
        ];
        const latestSeverityCount = mockSeverityCountsWithData().data.project
          .vulnerabilitySeveritiesCount[severity];

        const [lastSeriesDate, lastSeriesCount] = series.data.at(-1);

        expect(lastSeriesDate).toBe(todayIso);
        expect(lastSeriesCount).toBe(latestSeverityCount);
        expect(lastSeriesCount).not.toBe(todaysTrendingSeverityCount);
      },
    );

    it('should display the chart with responsive attribute', () => {
      expect(findLineChart().attributes('responsive')).toBeDefined();
    });

    it('should not display the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it.each([['restore'], ['saveAsImage']])('should contain %i icon', (icon) => {
      const option = findLineChart().props('option').toolbox.feature;
      expect(option[icon].icon).toBe('path://mockSvgPathContent');
    });

    it('contains dataZoom config', () => {
      const option = findLineChart().props('option').toolbox.feature;
      expect(option.dataZoom.icon.zoom).toBe('path://mockSvgPathContent');
      expect(option.dataZoom.icon.back).toBe('path://mockSvgPathContent');
    });

    it('contains the timeline slider', () => {
      const { dataZoom } = findLineChart().props('option');
      expect(dataZoom[0]).toMatchObject({
        type: 'slider',
        handleIcon: 'path://mockSvgPathContent',
        startValue: '2021-03-12',
      });
    });

    it('contains a promotion for the security training feature', () => {
      expect(findSecurityTrainingPromoBanner().exists()).toBe(true);
    });
  });
});
