import { GlStackedColumnChart } from '@gitlab/ui/dist/charts';
import { GlAlert, GlCard, GlSkeletonLoader, GlIcon } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import DoraPerformersScore from 'ee/analytics/dashboards/components/dora_performers_score.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import groupDoraPerformanceScoreCountsQuery from 'ee/analytics/dashboards/graphql/group_dora_performance_score_counts.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { DORA_PERFORMERS_SCORE_CHART_COLOR_PALETTE } from 'ee/analytics/dashboards/constants';
import getGroupOrProject from 'ee/analytics/dashboards/graphql/get_group_or_project.query.graphql';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { mockGraphqlDoraPerformanceScoreCountsResponse } from '../helpers';
import {
  mockDoraPerformersScoreChartData,
  mockEmptyDoraPerformersScoreResponseData,
} from '../mock_data';

Vue.use(VueApollo);

describe('DoraPerformersScore', () => {
  const fullPath = 'toolbox';
  const groupName = 'Toolbox';
  const mockData = { namespace: fullPath };
  const mockProjectsCount = 70;
  const mockGroup = {
    __typename: TYPENAME_GROUP,
    id: 'gid://gitlab/Group/22',
    name: groupName,
    webUrl: 'gdk.test/groups/toolbox',
  };
  const mockProject = {
    __typename: TYPENAME_PROJECT,
    id: 'gid://gitlab/Project/22',
    name: 'Hammer',
    webUrl: 'gdk.test/toolbox/hammer',
  };
  const doraPerformanceScoreCountsSuccess = mockGraphqlDoraPerformanceScoreCountsResponse({
    totalProjectsCount: mockProjectsCount,
  });
  const noProjectsWithDoraData = mockGraphqlDoraPerformanceScoreCountsResponse({
    totalProjectsCount: mockProjectsCount,
    noDoraDataProjectsCount: mockProjectsCount,
    mockDataResponse: mockEmptyDoraPerformersScoreResponseData,
  });
  const higherNoDoraDataProjectsCount = mockGraphqlDoraPerformanceScoreCountsResponse({
    totalProjectsCount: mockProjectsCount,
    noDoraDataProjectsCount: mockProjectsCount + 1,
    mockDataResponse: mockEmptyDoraPerformersScoreResponseData,
  });
  const queryError = jest.fn().mockRejectedValueOnce(new Error('Something went wrong'));
  const loadingErrorMessage = `Failed to load DORA performance scores for Namespace: ${fullPath}`;
  const projectNamespaceErrorMessage =
    'This visualization is not supported for project namespaces.';
  const mockGroupBy = [
    'Deployment Frequency (Velocity)',
    'Lead Time for Changes (Velocity)',
    'Time to Restore Service (Quality)',
    'Change Failure Rate (Quality)',
  ];
  const defaultGlFeatures = { doraPerformersScorePanel: true };
  const panelTitleWithProjectsCount = (projectsCount = mockProjectsCount) =>
    `Total projects (${projectsCount}) with DORA performers score for ${groupName} group`;

  let wrapper;
  let mockApollo;

  const createWrapper = async ({
    props = {},
    group = mockGroup,
    project = null,
    doraPerformanceScoreCountsHandler = doraPerformanceScoreCountsSuccess,
    glFeatures = defaultGlFeatures,
  } = {}) => {
    mockApollo = createMockApollo([
      [groupDoraPerformanceScoreCountsQuery, doraPerformanceScoreCountsHandler],
      [getGroupOrProject, jest.fn().mockResolvedValue({ data: { group, project } })],
    ]);

    wrapper = shallowMountExtended(DoraPerformersScore, {
      apolloProvider: mockApollo,
      propsData: {
        data: mockData,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: {
        GlCard,
      },
      provide: {
        glFeatures,
      },
    });

    await waitForPromises();
  };

  const findDoraPerformersScorePanel = () => wrapper.findByTestId('dora-performers-score-panel');
  const findDoraPerformersScoreChart = () => wrapper.findComponent(GlStackedColumnChart);
  const findDoraPerformersScorePanelTitle = () =>
    wrapper.findByTestId('dora-performers-score-panel-title');
  const findChartSkeletonLoader = () => wrapper.findComponent(ChartSkeletonLoader);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findPanelTitleHelpIcon = () => wrapper.findComponent(GlIcon);
  const findExcludedProjectsTooltip = () =>
    getBinding(findPanelTitleHelpIcon().element, 'gl-tooltip');

  afterEach(() => {
    mockApollo = null;
  });

  describe('default', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders panel title with total project count', () => {
      expect(findDoraPerformersScorePanelTitle().text()).toBe(panelTitleWithProjectsCount());
    });

    it('does not render panel title tooltip', () => {
      expect(findPanelTitleHelpIcon().exists()).toBe(false);
    });

    it('renders the chart', () => {
      expect(findDoraPerformersScoreChart().props()).toMatchObject({
        bars: mockDoraPerformersScoreChartData,
        customPalette: DORA_PERFORMERS_SCORE_CHART_COLOR_PALETTE,
        groupBy: mockGroupBy,
        presentation: 'tiled',
        xAxisType: 'category',
        xAxisTitle: '',
        yAxisTitle: '',
      });
    });
  });

  describe('when projects with no DORA data have been excluded', () => {
    describe.each`
      totalProjectsCount | noDoraDataProjectsCount | projectsCountWithDoraData | tooltipText
      ${20}              | ${10}                   | ${10}                     | ${'Excluding 10 projects with no DORA metrics'}
      ${5}               | ${1}                    | ${4}                      | ${'Excluding 1 project with no DORA metrics'}
    `(
      'renders tooltip in panel title with correct number of excluded projects',
      ({ totalProjectsCount, noDoraDataProjectsCount, projectsCountWithDoraData, tooltipText }) => {
        beforeEach(async () => {
          await createWrapper({
            doraPerformanceScoreCountsHandler: mockGraphqlDoraPerformanceScoreCountsResponse({
              totalProjectsCount,
              noDoraDataProjectsCount,
            }),
          });
        });

        it('renders panel title with correct total projects count with DORA data', () => {
          expect(findDoraPerformersScorePanelTitle().text()).toBe(
            panelTitleWithProjectsCount(projectsCountWithDoraData),
          );
        });

        it('renders tooltip in panel title with correct number of excluded projects', () => {
          expect(findExcludedProjectsTooltip().value).toBe(tooltipText);
        });
      },
    );
  });

  describe('when fetching data', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders chart skeleton loader', () => {
      expect(findChartSkeletonLoader().exists()).toBe(true);
    });

    it('renders skeleton loader instead of panel title', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findDoraPerformersScorePanelTitle().exists()).toBe(false);
    });
  });

  describe.each`
    emptyState                                          | response
    ${'noDoraDataProjectsCount === totalProjectsCount'} | ${noProjectsWithDoraData}
    ${'noDoraDataProjectsCount > totalProjectsCount'}   | ${higherNoDoraDataProjectsCount}
  `('when $emptyState', ({ response }) => {
    beforeEach(async () => {
      await createWrapper({ doraPerformanceScoreCountsHandler: response });
    });

    it('renders empty state message', () => {
      const noDataMessage = `No data available for Namespace: ${fullPath}`;
      expect(wrapper.findByText(noDataMessage).exists()).toBe(true);
    });

    it('renders panel title with `0` projects with DORA data', () => {
      expect(findDoraPerformersScorePanelTitle().text()).toBe(panelTitleWithProjectsCount(0));
    });

    it('does not render panel title tooltip', () => {
      expect(findPanelTitleHelpIcon().exists()).toBe(false);
    });

    it('does not render chart', () => {
      expect(findDoraPerformersScoreChart().exists()).toBe(false);
    });
  });

  describe.each`
    error                                         | props                                                | expectedErrorMessage
    ${'it fails to fetch DORA performers scores'} | ${{ doraPerformanceScoreCountsHandler: queryError }} | ${loadingErrorMessage}
    ${'namespace is `null`'}                      | ${{ group: null }}                                   | ${loadingErrorMessage}
    ${'namespace is project'}                     | ${{ group: null, project: mockProject }}             | ${projectNamespaceErrorMessage}
  `('when $error', ({ props, expectedErrorMessage }) => {
    beforeEach(async () => {
      await createWrapper(props);
    });

    it('renders alert component', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe(expectedErrorMessage);
    });

    it('renders default panel title', () => {
      expect(wrapper.findByText('Total projects with DORA performers score').exists()).toBe(true);
    });

    it('does not render panel title tooltip', () => {
      expect(findPanelTitleHelpIcon().exists()).toBe(false);
    });

    it('does not render chart', () => {
      expect(findDoraPerformersScoreChart().exists()).toBe(false);
    });
  });

  it('does not render if "doraPerformersScorePanel" feature flag is disabled', async () => {
    await createWrapper({ glFeatures: { doraPerformersScorePanel: false } });

    expect(findDoraPerformersScorePanel().exists()).toBe(false);
  });
});
