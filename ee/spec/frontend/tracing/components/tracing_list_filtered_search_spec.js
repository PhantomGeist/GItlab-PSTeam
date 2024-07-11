import { GlFilteredSearch } from '@gitlab/ui';
import OperationToken from 'ee/tracing/components/operation_search_token.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ServiceToken from 'ee/tracing/components/service_search_token.vue';
import TracingListFilteredSearch from 'ee/tracing/components/tracing_list_filtered_search.vue';
import { createMockClient } from 'helpers/mock_observability_client';

describe('TracingListFilteredSearch', () => {
  let wrapper;
  let observabilityClientMock;

  const initialFilters = [
    { type: 'period', value: '1h' },
    { type: 'service_name', value: 'example-service' },
  ];

  beforeEach(() => {
    observabilityClientMock = createMockClient();

    wrapper = shallowMountExtended(TracingListFilteredSearch, {
      propsData: {
        initialFilters,
        observabilityClient: observabilityClientMock,
      },
    });
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('sets initialFilters prop correctly', () => {
    expect(wrapper.findComponent(GlFilteredSearch).props('value')).toEqual(initialFilters);
  });

  it('emits submit event on filtered search submit', () => {
    wrapper
      .findComponent(GlFilteredSearch)
      .vm.$emit('submit', { filters: [{ type: 'period', value: '1h' }] });

    expect(wrapper.emitted('submit')).toHaveLength(1);
    expect(wrapper.emitted('submit')[0][0]).toEqual({
      filters: [{ type: 'period', value: '1h' }],
    });
  });

  describe('service token', () => {
    it('configure the service token', () => {
      const tokens = wrapper.findComponent(GlFilteredSearch).props('availableTokens');
      const serviceToken = tokens.find((t) => t.type === 'service-name');
      expect(serviceToken.token).toBe(ServiceToken);
      expect(serviceToken.fetchServices).toBe(observabilityClientMock.fetchServices);
    });
  });

  describe('operations token', () => {
    it('configure the service token', () => {
      const tokens = wrapper.findComponent(GlFilteredSearch).props('availableTokens');
      const operationToken = tokens.find((t) => t.type === 'operation');
      expect(operationToken.token).toBe(OperationToken);
      expect(operationToken.fetchOperations).toBe(observabilityClientMock.fetchOperations);
    });

    it('sets loadSuggestionsForServices based on the existing service filter', () => {
      wrapper = shallowMountExtended(TracingListFilteredSearch, {
        propsData: {
          initialFilters: [
            { type: 'service-name', value: { operator: '=', data: 'a-service' } },
            { type: 'service-name', value: { operator: '!=', data: 'unsupported-operator' } },
            { type: 'trace-id', value: { operator: '=', data: 'a-trace-id' } },
          ],
          observabilityClient: observabilityClientMock,
        },
      });

      const operationToken = wrapper
        .findComponent(GlFilteredSearch)
        .props('availableTokens')
        .find((t) => t.type === 'operation');
      expect(operationToken.loadSuggestionsForServices).toStrictEqual(['a-service']);
    });
  });
});
