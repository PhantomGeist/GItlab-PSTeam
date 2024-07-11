import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListIndex from 'ee/metrics/list_index.vue';
import MetricsList from 'ee/metrics/list/metrics_list.vue';
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

  it('renders ProvisionedObservabilityContainer component', () => {
    mountComponent();

    expect(wrapper.findComponent(ProvisionedObservabilityContainer).props()).toMatchObject(props);
  });

  it('renders MetricsList component inside ProvisionedObservabilityContainer', () => {
    mountComponent();

    const observabilityContainer = wrapper.findComponent(ProvisionedObservabilityContainer);
    expect(observabilityContainer.findComponent(MetricsList).exists()).toBe(true);
  });
});
