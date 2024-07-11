import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ObservabilityContainer from '~/observability/components/observability_container.vue';
import ObservabilityLoader from '~/observability/components/loader/index.vue';
import { CONTENT_STATE } from '~/observability/components/loader/constants';

import { buildClient } from '~/observability/client';

jest.mock('~/observability/client');

describe('ObservabilityContainer', () => {
  let wrapper;

  const OAUTH_URL = 'https://example.com/oauth';
  const TRACING_URL = 'https://example.com/tracing';
  const PROVISIONING_URL = 'https://example.com/provisioning';
  const SERVICES_URL = 'https://example.com/services';
  const OPERATIONS_URL = 'https://example.com/operations';

  const mockClient = { mock: 'client' };

  beforeEach(() => {
    jest.spyOn(console, 'error').mockImplementation();

    buildClient.mockReturnValue(mockClient);

    wrapper = shallowMountExtended(ObservabilityContainer, {
      propsData: {
        oauthUrl: OAUTH_URL,
        tracingUrl: TRACING_URL,
        provisioningUrl: PROVISIONING_URL,
        servicesUrl: SERVICES_URL,
        operationsUrl: OPERATIONS_URL,
      },
      slots: {
        default: {
          render(h) {
            h(`<div>mockedComponent</div>`);
          },
          name: 'MockComponent',
        },
      },
    });
  });

  const dispatchMessageEvent = (status, origin) =>
    window.dispatchEvent(
      new MessageEvent('message', {
        data: {
          type: 'AUTH_COMPLETION',
          status,
        },
        origin: origin ?? new URL(OAUTH_URL).origin,
      }),
    );

  const findIframe = () => wrapper.findByTestId('observability-oauth-iframe');
  const findSlotComponent = () => wrapper.findComponent({ name: 'MockComponent' });
  const findLoader = () => wrapper.findComponent(ObservabilityLoader);

  it('should render the oauth iframe', () => {
    const iframe = findIframe();
    expect(iframe.exists()).toBe(true);
    expect(iframe.attributes('hidden')).toBe('hidden');
    expect(iframe.attributes('src')).toBe(OAUTH_URL);
    expect(iframe.attributes('sandbox')).toBe('allow-same-origin allow-forms allow-scripts');
  });

  it('should render the ObservabilityLoader', () => {
    expect(findLoader().exists()).toBe(true);
  });

  it('should not render the default slot', () => {
    expect(findSlotComponent().exists()).toBe(false);
  });

  it('should not emit observability-client-ready', () => {
    expect(wrapper.emitted('observability-client-ready')).toBeUndefined();
  });

  describe('on oauth success message', () => {
    beforeEach(async () => {
      dispatchMessageEvent('success');

      await nextTick();
    });

    it('sets the loader contentState to LOADED', () => {
      expect(findLoader().props('contentState')).toBe(CONTENT_STATE.LOADED);
    });

    it('renders the slot content', () => {
      const slotComponent = findSlotComponent();
      expect(slotComponent.exists()).toBe(true);
    });

    it('build the observability client', () => {
      expect(buildClient).toHaveBeenCalledWith({
        provisioningUrl: PROVISIONING_URL,
        tracingUrl: TRACING_URL,
        servicesUrl: SERVICES_URL,
        operationsUrl: OPERATIONS_URL,
      });
    });

    it('emits observability-client-ready', () => {
      expect(wrapper.emitted('observability-client-ready')).toEqual([[mockClient]]);
    });
  });

  describe('on oauth error message', () => {
    beforeEach(async () => {
      dispatchMessageEvent('error');

      await nextTick();
    });

    it('set the loader contentState to ERROR', () => {
      expect(findLoader().props('contentState')).toBe(CONTENT_STATE.ERROR);
    });

    it('does not renders the slot content', () => {
      expect(findSlotComponent().exists()).toBe(false);
    });

    it('does not build the observability client', () => {
      expect(buildClient).not.toHaveBeenCalled();
    });

    it('does not emit observability-client-ready', () => {
      expect(wrapper.emitted('observability-client-ready')).toBeUndefined();
    });
  });

  it('handles oauth message only once', async () => {
    dispatchMessageEvent('success');
    dispatchMessageEvent('error');

    await nextTick();

    expect(buildClient).toHaveBeenCalledTimes(1);
    expect(findLoader().props('contentState')).toBe(CONTENT_STATE.LOADED);
  });

  it('only handles messages from the oauth url', () => {
    dispatchMessageEvent('success', 'www.fake-url.com');

    expect(findLoader().props('contentState')).toBe(null);
    expect(findSlotComponent().exists()).toBe(false);
    expect(findIframe().exists()).toBe(true);
  });

  it('does not handle messages if the component has been destroyed', () => {
    wrapper.destroy();

    dispatchMessageEvent('success');

    expect(findLoader().props('contentState')).toBe(null);
  });
});
