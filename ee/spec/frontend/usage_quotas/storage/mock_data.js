import mockGetNamespaceStorageStatisticsGraphQLResponse from 'test_fixtures/graphql/usage_quotas/storage/namespace_storage.query.graphql.json';
import { storageTypeHelpPaths } from '~/usage_quotas/storage/constants';

export { mockGetNamespaceStorageStatisticsGraphQLResponse };

export const projects =
  mockGetNamespaceStorageStatisticsGraphQLResponse.data.namespace.projects.nodes;

export const defaultNamespaceProvideValues = {
  namespaceId: '42',
  namespacePath: 'h5bp',
  userNamespace: false,
  defaultPerPage: 20,
  purchaseStorageUrl: 'some-fancy-url',
  buyAddonTargetAttr: '_blank',
  namespacePlanName: 'Free',
  namespacePlanStorageIncluded: 1002321,
  totalRepositorySizeExcess: '0',
  isUsingProjectEnforcement: true,
  isUsingNamespaceEnforcement: false,
  helpLinks: storageTypeHelpPaths,
};

export const namespaceData = {
  totalUsage: 'Not applicable.',
  limit: 10000000,
  projects: { data: projects },
};

export const withRootStorageStatistics = {
  projects,
  limit: 10000000,
  totalUsage: 129334601,
  containsLockedProjects: true,
  repositorySizeExcessProjectCount: 1,
  totalRepositorySizeExcess: 2321,
  totalRepositorySize: 1002321,
  additionalPurchasedStorageSize: 321,
  actualRepositorySizeLimit: 1002321,
  rootStorageStatistics: {
    containerRegistrySize: 3900000,
    containerRegistrySizeIsEstimated: true,
    storageSize: 129334601,
    costFactoredStorageSize: 12933460,
    repositorySize: 46012030,
    lfsObjectsSize: 4329334601203,
    buildArtifactsSize: 1272375,
    packagesSize: 123123120,
    wikiSize: 1000,
    snippetsSize: 10000,
  },
};

export const statisticsCardDefaultProps = {
  totalStorage: 100 * 1024,
  usedStorage: 50 * 1024,
  planStorageDescription: 'Storage per project included in Free subscription',
  loading: false,
};

export const mockedNamespaceStorageResponse = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/84',
      name: 'wandercatgroup2',
      storageSizeLimit: 0,
      actualRepositorySizeLimit: 10737418240,
      additionalPurchasedStorageSize: 0,
      totalRepositorySizeExcess: 0,
      totalRepositorySize: 20971,
      containsLockedProjects: false,
      repositorySizeExcessProjectCount: 0,
      rootStorageStatistics: {
        containerRegistrySize: 3900000,
        containerRegistrySizeIsEstimated: true,
        storageSize: 125771,
        costFactoredStorageSize: 12577,
        repositorySize: 20971,
        lfsObjectsSize: 0,
        buildArtifactsSize: 0,
        packagesSize: 0,
        wikiSize: 104800,
        snippetsSize: 0,
        __typename: 'RootStorageStatistics',
      },
      projects: {
        nodes: [
          {
            id: 'gid://gitlab/Project/20',
            fullPath: 'wandercatgroup2/not-so-empty-project',
            nameWithNamespace: 'wandercatgroup2 / not so empty project',
            avatarUrl: null,
            webUrl: 'http://gdk.test:3000/wandercatgroup2/not-so-empty-project',
            name: 'not so empty project',
            repositorySizeExcess: 0,
            actualRepositorySizeLimit: 10737418240,
            statistics: {
              commitCount: 1,
              storageSize: 125771,
              costFactoredStorageSize: 12577,
              repositorySize: 20971,
              lfsObjectsSize: 0,
              containerRegistrySize: 0,
              buildArtifactsSize: 0,
              packagesSize: 0,
              wikiSize: 104800,
              snippetsSize: 0,
              __typename: 'ProjectStatistics',
            },
            __typename: 'Project',
          },
          {
            id: 'gid://gitlab/Project/21',
            fullPath: 'wandercatgroup2/not-so-empty-project1',
            nameWithNamespace: 'wandercatgroup2 / not so empty project',
            avatarUrl: null,
            webUrl: 'http://gdk.test:3000/wandercatgroup2/not-so-empty-project',
            name: 'not so empty project',
            repositorySizeExcess: 0,
            actualRepositorySizeLimit: 10737418240,
            statistics: {
              commitCount: 1,
              storageSize: 125771,
              costFactoredStorageSize: 12577,
              repositorySize: 20971,
              lfsObjectsSize: 0,
              containerRegistrySize: 0,
              buildArtifactsSize: 0,
              packagesSize: 0,
              wikiSize: 104800,
              snippetsSize: 0,
              __typename: 'ProjectStatistics',
            },
            __typename: 'Project',
          },
        ],
        pageInfo: {
          __typename: 'PageInfo',
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: 'eyJpZCI6IjIwIiwiZXhjZXNzX3N0b3JhZ2UiOiItMTA3MzczOTcyNjkifQ',
          endCursor: 'eyJpZCI6IjIwIiwiZXhjZXNzX3N0b3JhZ2UiOiItMTA3MzczOTcyNjkifQ',
        },
        __typename: 'ProjectConnection',
      },
      __typename: 'Namespace',
    },
  },
};

export const mockDependencyProxyResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/84',
      dependencyProxyTotalSizeBytes: '0',
      __typename: 'Group',
    },
  },
};
