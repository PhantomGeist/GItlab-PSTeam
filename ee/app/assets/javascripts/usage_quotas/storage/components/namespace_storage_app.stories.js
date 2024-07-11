import {
  mockDependencyProxyResponse,
  mockedNamespaceStorageResponse,
} from 'ee_jest/usage_quotas/storage/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import { storageTypeHelpPaths as helpLinks } from '~/usage_quotas/storage/constants';
import getNamespaceStorageQuery from 'ee/usage_quotas/storage/queries/namespace_storage.query.graphql';
import getDependencyProxyTotalSizeQuery from 'ee/usage_quotas/storage/queries/dependency_proxy_usage.query.graphql';
import NamespaceStorageApp from './namespace_storage_app.vue';

const meta = {
  title: 'ee/usage_quotas/storage/namespace_storage_app',
  component: NamespaceStorageApp,
};

export default meta;

const MEBIBYTE = 1024 * 1024; // bytes in a mebibyte

const createTemplate = (config = {}) => {
  let { provide, apolloProvider } = config;

  if (provide == null) {
    provide = {};
  }

  if (apolloProvider == null) {
    const requestHandlers = [
      [getNamespaceStorageQuery, () => Promise.resolve(mockedNamespaceStorageResponse)],
      [getDependencyProxyTotalSizeQuery, () => Promise.resolve(mockDependencyProxyResponse)],
    ];
    apolloProvider = createMockApollo(requestHandlers);
  }

  return (args, { argTypes }) => ({
    components: { NamespaceStorageApp },
    apolloProvider,
    provide: {
      namespaceId: '1',
      namespacePath: '/namespace/',
      userNamespace: false,
      defaultPerPage: 20,
      namespacePlanName: 'free',
      namespacePlanStorageIncluded: 10 * MEBIBYTE,
      purchaseStorageUrl: '//purchase-storage-url',
      buyAddonTargetAttr: 'buyAddonTargetAttr',
      enforcementType: 'namespace_storage_limit',
      isUsingNamespaceEnforcement: true,
      isUsingProjectEnforcement: false,
      helpLinks,
      ...provide,
    },
    props: Object.keys(argTypes),
    template: '<namespace-storage-app />',
  });
};

export const SaasWithNamespaceLimits = {
  render: createTemplate(),
};

export const SaasWithNamespaceLimitsLoading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceStorageQuery, () => new Promise(() => {})],
      [getDependencyProxyTotalSizeQuery, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
      provide: {
        isUsingProjectEnforcement: false,
      },
    })(...args);
  },
};

export const SaasWithProjectLimits = {
  render: createTemplate({
    provide: {
      enforcementType: 'project_repository_limit',
      isUsingNamespaceEnforcement: false,
      isUsingProjectEnforcement: true,
      totalRepositorySizeExcess: MEBIBYTE,
    },
  }),
};

export const SaasWithProjectLimitsLoading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceStorageQuery, () => new Promise(() => {})],
      [getDependencyProxyTotalSizeQuery, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
      provide: {
        enforcementType: 'project_repository_limit',
        isUsingNamespaceEnforcement: false,
        isUsingProjectEnforcement: true,
        totalRepositorySizeExcess: MEBIBYTE,
      },
    })(...args);
  },
};

export const SaasLoadingError = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceStorageQuery, () => Promise.reject()],
      [getDependencyProxyTotalSizeQuery, () => Promise.reject()],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};

const selfManagedDefaultProvide = {
  isUsingProjectEnforcement: false,
  isUsingNamespaceEnforcement: false,
  namespacePlanName: null,
  namespaceStorageIncluded: '',
  namespacePlanStorageIncluded: 0,
  purchaseStorageUrl: null,
  buyAddonTargetAttr: null,
};

export const SelfManaged = {
  render: createTemplate({
    provide: {
      ...selfManagedDefaultProvide,
    },
  }),
};

export const SelfManagedLoading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [getNamespaceStorageQuery, () => new Promise(() => {})],
      [getDependencyProxyTotalSizeQuery, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
      provide: {
        ...selfManagedDefaultProvide,
      },
    })(...args);
  },
};
