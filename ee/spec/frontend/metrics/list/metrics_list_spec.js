import { GlLoadingIcon } from '@gitlab/ui';
import MetricsTable from 'ee/metrics/list/metrics_table.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MetricsList from 'ee/metrics/list/metrics_list.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { mockMetrics } from './mock_data';

jest.mock('~/alert');

describe('MetricsComponent', () => {
  let wrapper;
  let observabilityClientMock;

  const mockResponse = {
    metrics: [...mockMetrics],
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findMetricsTable = () => wrapper.findComponent(MetricsTable);

  const mountComponent = async () => {
    wrapper = shallowMountExtended(MetricsList, {
      propsData: {
        observabilityClient: observabilityClientMock,
      },
    });
    await waitForPromises();
  };

  beforeEach(() => {
    observabilityClientMock = {
      fetchMetrics: jest.fn().mockResolvedValue(mockResponse),
    };
  });

  it('renders the loading indicator while fetching metrics', () => {
    mountComponent();

    expect(findLoadingIcon().exists()).toBe(true);
    expect(findMetricsTable().exists()).toBe(false);
    expect(observabilityClientMock.fetchMetrics).toHaveBeenCalled();
  });

  it('renders the MetricsTable when fetching metrics is done', async () => {
    await mountComponent();

    expect(findLoadingIcon().exists()).toBe(false);
    expect(findMetricsTable().exists()).toBe(true);
    expect(findMetricsTable().props('metrics')).toEqual(mockResponse.metrics);
  });

  it('calls fetchMetrics method when MetricsTable emits reload event', async () => {
    await mountComponent();

    observabilityClientMock.fetchMetrics.mockClear();

    findMetricsTable().vm.$emit('reload');

    expect(observabilityClientMock.fetchMetrics).toHaveBeenCalledTimes(1);
  });

  it('if fetchMetrics fails, it renders an alert and empty list', async () => {
    observabilityClientMock.fetchMetrics.mockRejectedValue('error');

    await mountComponent();

    expect(createAlert).toHaveBeenLastCalledWith({ message: 'Failed to load metrics.' });
    expect(findMetricsTable().exists()).toBe(true);
    expect(findMetricsTable().props('metrics')).toEqual([]);
  });
});
