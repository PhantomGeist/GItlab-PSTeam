import { GlTabs } from '@gitlab/ui';
import Api from '~/api';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import stubChildren from 'helpers/stub_children';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SecurityConfigurationApp from '~/security_configuration/components/app.vue';
import UpgradeBanner from 'ee/security_configuration/components/upgrade_banner.vue';
import { securityFeaturesMock, provideMock } from 'jest/security_configuration/mock_data';
import { SERVICE_PING_SECURITY_CONFIGURATION_THREAT_MANAGEMENT_VISIT } from '~/tracking/constants';
import { TAB_VULNERABILITY_MANAGEMENT_INDEX } from '~/security_configuration/components/constants';

jest.mock('~/api.js');

describe('~/security_configuration/components/app', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createComponent = ({ shouldShowCallout = true, ...propsData } = {}) => {
    userCalloutDismissSpy = jest.fn();

    wrapper = mountExtended(SecurityConfigurationApp, {
      propsData: {
        augmentedSecurityFeatures: securityFeaturesMock,
        securityTrainingEnabled: true,
        ...propsData,
      },
      provide: provideMock,
      stubs: {
        ...stubChildren(SecurityConfigurationApp),
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
        UpgradeBanner: false,
      },
    });
  };

  const findUpgradeBanner = () => wrapper.findComponent(UpgradeBanner);
  const findTabsComponent = () => wrapper.findComponent(GlTabs);

  describe('upgrade banner', () => {
    const makeAvailable = (available) => (feature) => ({ ...feature, available });

    describe('given at least one unavailable feature', () => {
      beforeEach(() => {
        createComponent({
          augmentedSecurityFeatures: [
            {
              ...securityFeaturesMock[0],
              available: false,
            },
          ],
        });
      });

      it('renders the banner', () => {
        expect(findUpgradeBanner().exists()).toBe(true);
      });

      it('calls the dismiss callback when closing the banner', () => {
        expect(userCalloutDismissSpy).not.toHaveBeenCalled();

        findUpgradeBanner().vm.$emit('close');

        expect(userCalloutDismissSpy).toHaveBeenCalledTimes(1);
      });
    });

    describe('given at least one unavailable feature, but banner is already dismissed', () => {
      beforeEach(() => {
        createComponent({
          shouldShowCallout: false,
        });
      });

      it('does not render the banner', () => {
        expect(findUpgradeBanner().exists()).toBe(false);
      });
    });

    describe('given all features are available', () => {
      beforeEach(() => {
        createComponent({
          augmentedSecurityFeatures: securityFeaturesMock.map(makeAvailable(true)),
        });
      });

      it('does not render the banner', () => {
        expect(findUpgradeBanner().exists()).toBe(false);
      });
    });
  });

  describe('tab change', () => {
    beforeEach(() => {
      createComponent();
    });

    it('tracks "users_visiting_security_configuration_threat_management" when threat management tab is selected', () => {
      findTabsComponent().vm.$emit('input', TAB_VULNERABILITY_MANAGEMENT_INDEX);

      expect(Api.trackRedisHllUserEvent).toHaveBeenCalledTimes(1);
      expect(Api.trackRedisHllUserEvent).toHaveBeenCalledWith(
        SERVICE_PING_SECURITY_CONFIGURATION_THREAT_MANAGEMENT_VISIT,
      );
    });

    it("doesn't track the metric when other tab is selected", () => {
      findTabsComponent().vm.$emit('input', 0);

      expect(Api.trackRedisHllUserEvent).not.toHaveBeenCalled();
    });
  });
});
