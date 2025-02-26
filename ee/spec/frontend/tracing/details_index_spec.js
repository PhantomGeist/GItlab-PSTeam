import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DetailsIndex from 'ee/tracing/details_index.vue';
import TracingDetails from 'ee/tracing/components/tracing_details.vue';
import ObservabilityContainer from '~/observability/components/observability_container.vue';

describe('DetailsIndex', () => {
  const props = {
    traceId: 'test-trace-id',
    tracingIndexUrl: 'https://example.com/tracing/index',
    oauthUrl: 'https://example.com/oauth',
    tracingUrl: 'https://example.com/tracing',
    provisioningUrl: 'https://example.com/provisioning',
    servicesUrl: 'https://example.com/services',
    operationsUrl: 'https://example.com/operations',
  };

  let wrapper;

  const mountComponent = () => {
    wrapper = shallowMountExtended(DetailsIndex, {
      propsData: props,
    });
  };

  it('renders ObservabilityContainer component', () => {
    mountComponent();

    const observabilityContainer = wrapper.findComponent(ObservabilityContainer);
    expect(observabilityContainer.exists()).toBe(true);
    expect(observabilityContainer.props('oauthUrl')).toBe(props.oauthUrl);
    expect(observabilityContainer.props('tracingUrl')).toBe(props.tracingUrl);
    expect(observabilityContainer.props('provisioningUrl')).toBe(props.provisioningUrl);
    expect(observabilityContainer.props('servicesUrl')).toBe(props.servicesUrl);
    expect(observabilityContainer.props('operationsUrl')).toBe(props.operationsUrl);
  });

  it('renders TracingList component inside ObservabilityContainer', () => {
    mountComponent();

    const observabilityContainer = wrapper.findComponent(ObservabilityContainer);
    const detailsCmp = observabilityContainer.findComponent(TracingDetails);
    expect(detailsCmp.exists()).toBe(true);
    expect(detailsCmp.props('traceId')).toBe(props.traceId);
    expect(detailsCmp.props('tracingIndexUrl')).toBe(props.tracingIndexUrl);
  });
});
