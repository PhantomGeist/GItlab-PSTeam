import {
  mockGetCiMinutesUsageNamespace,
  mockGetCiMinutesUsageNamespaceProjects,
} from 'ee_jest/usage_quotas/pipelines/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import getGroupCiMinutesUsage from '../graphql/queries/ci_minutes.query.graphql';
import getGroupProjectsCiMinutesUsage from '../graphql/queries/ci_minutes_projects.query.graphql';
import PipelineUsageApp from './app.vue';

const meta = {
  title: 'ee/usage_quotas/pipelines/app',
  component: PipelineUsageApp,
};

export default meta;

const ciMinutesLastResetDate =
  mockGetCiMinutesUsageNamespaceProjects.data.ciMinutesUsage.nodes[0].monthIso8601;

const createTemplate = (config = {}) => {
  let { provide, apolloProvider } = config;

  if (provide == null) {
    provide = {};
  }

  if (apolloProvider == null) {
    const requestHandlers = [
      [getGroupCiMinutesUsage, () => Promise.resolve(mockGetCiMinutesUsageNamespace)],
      [
        getGroupProjectsCiMinutesUsage,
        ({ date }) => {
          // Return data only when a particular month is selected, for which we
          // have mocks.
          if (date === ciMinutesLastResetDate) {
            return Promise.resolve(mockGetCiMinutesUsageNamespaceProjects);
          }

          // Return an empty response otherwise
          return {
            data: {
              ciMinutesUsage: {
                nodes: [],
              },
            },
          };
        },
      ],
    ];
    apolloProvider = createMockApollo(requestHandlers);
  }

  return (args, { argTypes }) => ({
    components: { PipelineUsageApp },
    apolloProvider,
    provide: {
      pageSize: 20,
      namespacePath: 'test',
      namespaceId: '35',
      namespaceActualPlanName: 'free',
      userNamespace: false,
      ciMinutesAnyProjectEnabled: true,
      ciMinutesDisplayMinutesAvailableData: true,
      ciMinutesLastResetDate,
      ciMinutesMonthlyMinutesLimit: '400',
      ciMinutesMonthlyMinutesUsed: '0',
      ciMinutesMonthlyMinutesUsedPercentage: '0',
      ciMinutesPurchasedMinutesLimit: '0',
      ciMinutesPurchasedMinutesUsed: '0',
      ciMinutesPurchasedMinutesUsedPercentage: '0',
      buyAdditionalMinutesPath: '/-/subscriptions/buy_minutes?selected_group=35',
      buyAdditionalMinutesTarget: '_self',
      ...provide,
    },
    props: Object.keys(argTypes),
    template: '<pipeline-usage-app />',
  });
};

export const Default = {
  render: createTemplate(),
};

export const Loading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getGroupCiMinutesUsage, () => new Promise(() => {})],
      [getGroupProjectsCiMinutesUsage, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};

export const LoadingError = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getGroupCiMinutesUsage, () => Promise.reject()],
      [getGroupProjectsCiMinutesUsage, () => Promise.reject()],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};
