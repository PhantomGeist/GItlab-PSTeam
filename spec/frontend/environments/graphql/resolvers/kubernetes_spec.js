import MockAdapter from 'axios-mock-adapter';
import { CoreV1Api, AppsV1Api, BatchV1Api, WatchApi } from '@gitlab/cluster-client';
import axios from '~/lib/utils/axios_utils';
import { resolvers } from '~/environments/graphql/resolvers';
import { CLUSTER_AGENT_ERROR_MESSAGES } from '~/environments/constants';
import { k8sPodsMock, k8sServicesMock, k8sNamespacesMock } from '../mock_data';

describe('~/frontend/environments/graphql/resolvers', () => {
  let mockResolvers;
  let mock;

  const configuration = {
    basePath: 'kas-proxy/',
    baseOptions: {
      headers: { 'GitLab-Agent-Id': '1' },
    },
  };
  const namespace = 'default';

  beforeEach(() => {
    mockResolvers = resolvers();
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.reset();
  });

  describe('k8sPods', () => {
    const client = { writeQuery: jest.fn() };
    describe('when k8sWatchApi feature is disabled', () => {
      const mockPodsListFn = jest.fn().mockImplementation(() => {
        return Promise.resolve({
          items: k8sPodsMock,
        });
      });

      const mockNamespacedPodsListFn = jest.fn().mockImplementation(mockPodsListFn);
      const mockAllPodsListFn = jest.fn().mockImplementation(mockPodsListFn);

      beforeEach(() => {
        jest
          .spyOn(CoreV1Api.prototype, 'listCoreV1NamespacedPod')
          .mockImplementation(mockNamespacedPodsListFn);
        jest
          .spyOn(CoreV1Api.prototype, 'listCoreV1PodForAllNamespaces')
          .mockImplementation(mockAllPodsListFn);
      });

      it('should request namespaced pods from the cluster_client library if namespace is specified', async () => {
        const pods = await mockResolvers.Query.k8sPods(
          null,
          {
            configuration,
            namespace,
          },
          { client },
        );

        expect(mockNamespacedPodsListFn).toHaveBeenCalledWith({ namespace });
        expect(mockAllPodsListFn).not.toHaveBeenCalled();

        expect(pods).toEqual(k8sPodsMock);
      });
      it('should request all pods from the cluster_client library if namespace is not specified', async () => {
        const pods = await mockResolvers.Query.k8sPods(
          null,
          {
            configuration,
            namespace: '',
          },
          { client },
        );

        expect(mockAllPodsListFn).toHaveBeenCalled();
        expect(mockNamespacedPodsListFn).not.toHaveBeenCalled();

        expect(pods).toEqual(k8sPodsMock);
      });
      it('should throw an error if the API call fails', async () => {
        jest
          .spyOn(CoreV1Api.prototype, 'listCoreV1PodForAllNamespaces')
          .mockRejectedValue(new Error('API error'));

        await expect(
          mockResolvers.Query.k8sPods(null, { configuration }, { client }),
        ).rejects.toThrow('API error');
      });
    });

    describe('when k8sWatchApi feature is enabled', () => {
      const mockWatcher = WatchApi.prototype;
      const mockPodsListFn = jest.fn().mockImplementation(() => {
        return Promise.resolve(mockWatcher);
      });

      const mockOnDataFn = jest.fn().mockImplementation((eventName, callback) => {
        if (eventName === 'data') {
          callback(k8sPodsMock);
        }
      });
      const mockOnErrorFn = jest.fn().mockImplementation((eventName, callback) => {
        if (eventName === 'error') {
          const error = { message: 'API error' };
          callback(error);
        }
      });
      const mockOnTimeoutFn = jest.fn().mockImplementation((eventName, callback) => {
        if (eventName === 'timeout') {
          callback({});
        }
      });

      beforeEach(() => {
        gon.features = { k8sWatchApi: true };
        jest.spyOn(mockWatcher, 'subscribeToStream').mockImplementation(mockPodsListFn);
        jest.spyOn(mockWatcher, 'on').mockImplementation(mockOnDataFn);
      });

      it('should request namespaced pods from the cluster_client library if namespace is specified', () => {
        mockResolvers.Query.k8sPods(null, { configuration, namespace }, { client });

        expect(mockPodsListFn).toHaveBeenCalledWith(`/api/v1/namespaces/${namespace}/pods`, {
          watch: true,
        });
      });
      it('should request all pods from the cluster_client library if namespace is not specified', () => {
        mockResolvers.Query.k8sPods(null, { configuration, namespace: '' }, { client });

        expect(mockPodsListFn).toHaveBeenCalledWith(`/api/v1/pods`, { watch: true });
      });
      it('should return data when received from the library', async () => {
        const pods = await mockResolvers.Query.k8sPods(null, { configuration }, { client });

        expect(pods).toEqual(k8sPodsMock);
      });
      it('should throw an error when received from the library', async () => {
        jest.spyOn(mockWatcher, 'on').mockImplementation(mockOnErrorFn);

        await expect(
          mockResolvers.Query.k8sPods(null, { configuration }, { client }),
        ).rejects.toThrow('API error');
      });
      it('should return empty data when received timeout event from the library', async () => {
        jest.spyOn(mockWatcher, 'on').mockImplementation(mockOnTimeoutFn);

        await expect(
          mockResolvers.Query.k8sPods(null, { configuration }, { client }),
        ).resolves.toEqual([]);
      });
    });
  });
  describe('k8sServices', () => {
    const mockServicesListFn = jest.fn().mockImplementation(() => {
      return Promise.resolve({
        items: k8sServicesMock,
      });
    });

    const mockNamespacedServicesListFn = jest.fn().mockImplementation(mockServicesListFn);
    const mockAllServicesListFn = jest.fn().mockImplementation(mockServicesListFn);

    beforeEach(() => {
      jest
        .spyOn(CoreV1Api.prototype, 'listCoreV1ServiceForAllNamespaces')
        .mockImplementation(mockServicesListFn);

      jest
        .spyOn(CoreV1Api.prototype, 'listCoreV1NamespacedService')
        .mockImplementation(mockNamespacedServicesListFn);
      jest
        .spyOn(CoreV1Api.prototype, 'listCoreV1ServiceForAllNamespaces')
        .mockImplementation(mockAllServicesListFn);
    });

    it('should request namespaced services from the cluster_client library if namespace is specified', async () => {
      const services = await mockResolvers.Query.k8sServices(null, { configuration, namespace });

      expect(mockNamespacedServicesListFn).toHaveBeenCalledWith({ namespace });
      expect(mockAllServicesListFn).not.toHaveBeenCalled();

      expect(services).toEqual(k8sServicesMock);
    });
    it('should request all services from the cluster_client library if namespace is not specified', async () => {
      const services = await mockResolvers.Query.k8sServices(null, {
        configuration,
        namespace: '',
      });

      expect(mockServicesListFn).toHaveBeenCalled();
      expect(mockNamespacedServicesListFn).not.toHaveBeenCalled();

      expect(services).toEqual(k8sServicesMock);
    });
    it('should throw an error if the API call fails', async () => {
      jest
        .spyOn(CoreV1Api.prototype, 'listCoreV1ServiceForAllNamespaces')
        .mockRejectedValue(new Error('API error'));

      await expect(mockResolvers.Query.k8sServices(null, { configuration })).rejects.toThrow(
        'API error',
      );
    });
  });
  describe('k8sWorkloads', () => {
    const emptyImplementation = jest.fn().mockImplementation(() => {
      return Promise.resolve({
        data: {
          items: [],
        },
      });
    });

    const [
      mockNamespacedDeployment,
      mockNamespacedDaemonSet,
      mockNamespacedStatefulSet,
      mockNamespacedReplicaSet,
      mockNamespacedJob,
      mockNamespacedCronJob,
      mockAllDeployment,
      mockAllDaemonSet,
      mockAllStatefulSet,
      mockAllReplicaSet,
      mockAllJob,
      mockAllCronJob,
    ] = Array(12).fill(emptyImplementation);

    const namespacedMocks = [
      { method: 'listAppsV1NamespacedDeployment', api: AppsV1Api, spy: mockNamespacedDeployment },
      { method: 'listAppsV1NamespacedDaemonSet', api: AppsV1Api, spy: mockNamespacedDaemonSet },
      { method: 'listAppsV1NamespacedStatefulSet', api: AppsV1Api, spy: mockNamespacedStatefulSet },
      { method: 'listAppsV1NamespacedReplicaSet', api: AppsV1Api, spy: mockNamespacedReplicaSet },
      { method: 'listBatchV1NamespacedJob', api: BatchV1Api, spy: mockNamespacedJob },
      { method: 'listBatchV1NamespacedCronJob', api: BatchV1Api, spy: mockNamespacedCronJob },
    ];

    const allMocks = [
      { method: 'listAppsV1DeploymentForAllNamespaces', api: AppsV1Api, spy: mockAllDeployment },
      { method: 'listAppsV1DaemonSetForAllNamespaces', api: AppsV1Api, spy: mockAllDaemonSet },
      { method: 'listAppsV1StatefulSetForAllNamespaces', api: AppsV1Api, spy: mockAllStatefulSet },
      { method: 'listAppsV1ReplicaSetForAllNamespaces', api: AppsV1Api, spy: mockAllReplicaSet },
      { method: 'listBatchV1JobForAllNamespaces', api: BatchV1Api, spy: mockAllJob },
      { method: 'listBatchV1CronJobForAllNamespaces', api: BatchV1Api, spy: mockAllCronJob },
    ];

    beforeEach(() => {
      [...namespacedMocks, ...allMocks].forEach((workloadMock) => {
        jest
          .spyOn(workloadMock.api.prototype, workloadMock.method)
          .mockImplementation(workloadMock.spy);
      });
    });

    it('should request namespaced workload types from the cluster_client library if namespace is specified', async () => {
      await mockResolvers.Query.k8sWorkloads(null, { configuration, namespace });

      namespacedMocks.forEach((workloadMock) => {
        expect(workloadMock.spy).toHaveBeenCalledWith({ namespace });
      });
    });

    it('should request all workload types from the cluster_client library if namespace is not specified', async () => {
      await mockResolvers.Query.k8sWorkloads(null, { configuration, namespace: '' });

      allMocks.forEach((workloadMock) => {
        expect(workloadMock.spy).toHaveBeenCalled();
      });
    });
    it('should pass fulfilled calls data if one of the API calls fail', async () => {
      jest
        .spyOn(AppsV1Api.prototype, 'listAppsV1DeploymentForAllNamespaces')
        .mockRejectedValue(new Error('API error'));

      await expect(
        mockResolvers.Query.k8sWorkloads(null, { configuration }),
      ).resolves.toBeDefined();
    });
    it('should throw an error if all the API calls fail', async () => {
      [...allMocks].forEach((workloadMock) => {
        jest
          .spyOn(workloadMock.api.prototype, workloadMock.method)
          .mockRejectedValue(new Error('API error'));
      });

      await expect(mockResolvers.Query.k8sWorkloads(null, { configuration })).rejects.toThrow(
        'API error',
      );
    });
  });
  describe('k8sNamespaces', () => {
    const mockNamespacesListFn = jest.fn().mockImplementation(() => {
      return Promise.resolve({
        items: k8sNamespacesMock,
      });
    });

    beforeEach(() => {
      jest
        .spyOn(CoreV1Api.prototype, 'listCoreV1Namespace')
        .mockImplementation(mockNamespacesListFn);
    });

    it('should request all namespaces from the cluster_client library', async () => {
      const namespaces = await mockResolvers.Query.k8sNamespaces(null, { configuration });

      expect(mockNamespacesListFn).toHaveBeenCalled();

      expect(namespaces).toEqual(k8sNamespacesMock);
    });
    it.each([
      ['Unauthorized', CLUSTER_AGENT_ERROR_MESSAGES.unauthorized],
      ['Forbidden', CLUSTER_AGENT_ERROR_MESSAGES.forbidden],
      ['Not found', CLUSTER_AGENT_ERROR_MESSAGES['not found']],
      ['Unknown', CLUSTER_AGENT_ERROR_MESSAGES.other],
    ])(
      'should throw an error if the API call fails with the reason "%s"',
      async (reason, message) => {
        jest.spyOn(CoreV1Api.prototype, 'listCoreV1Namespace').mockRejectedValue({ reason });

        await expect(mockResolvers.Query.k8sNamespaces(null, { configuration })).rejects.toThrow(
          message,
        );
      },
    );
  });
});
