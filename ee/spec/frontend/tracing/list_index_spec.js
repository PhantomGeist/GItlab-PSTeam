import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListIndex from 'ee/tracing/list_index.vue';
import TracingList from 'ee/tracing/components/tracing_list.vue';
import ProvisionedObservabilityContainer from '~/observability/components/provisioned_observability_container.vue';

describe('ListIndex', () => {
  const props = {
    oauthUrl: 'https://example.com/oauth',
    tracingUrl: 'https://example.com/tracing',
    provisioningUrl: 'https://example.com/provisioning',
    servicesUrl: 'https://example.com/services',
    operationsUrl: 'https://example.com/operations',
  };

  let wrapper;

  const mountComponent = () => {
    wrapper = shallowMountExtended(ListIndex, {
      propsData: props,
    });
  };

  it('renders provisioned-observability-container component', () => {
    mountComponent();

    const observabilityContainer = wrapper.findComponent(ProvisionedObservabilityContainer);
    expect(observabilityContainer.exists()).toBe(true);
    expect(observabilityContainer.props('oauthUrl')).toBe(props.oauthUrl);
    expect(observabilityContainer.props('tracingUrl')).toBe(props.tracingUrl);
    expect(observabilityContainer.props('provisioningUrl')).toBe(props.provisioningUrl);
    expect(observabilityContainer.props('servicesUrl')).toBe(props.servicesUrl);
    expect(observabilityContainer.props('operationsUrl')).toBe(props.operationsUrl);
  });

  it('renders TracingList component inside ProvisionedObservabilityContainer', () => {
    mountComponent();

    const observabilityContainer = wrapper.findComponent(ProvisionedObservabilityContainer);
    expect(observabilityContainer.findComponent(TracingList).exists()).toBe(true);
  });
});
