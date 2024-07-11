import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlLink, GlSprintf, GlProgressBar } from '@gitlab/ui';
import StorageUsageOverviewCard from 'ee/usage_quotas/storage/components/storage_usage_overview_card.vue';
import NamespaceLimitsStorageUsageOverviewCard from 'ee/usage_quotas/storage/components/namespace_limits_storage_usage_overview_card.vue';
import NamespaceLimitsTotalStorageAvailableBreakdownCard from 'ee/usage_quotas/storage/components/namespace_limits_total_storage_available_breakdown_card.vue';
import ProjectLimitsExcessStorageBreakdownCard from 'ee/usage_quotas/storage/components/project_limits_excess_storage_breakdown_card.vue';
import NumberToHumanSize from 'ee/usage_quotas/storage/components/number_to_human_size.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_STORAGE_OVERVIEW_SUBTITLE } from 'ee/usage_quotas/storage/constants';
import StorageUsageStatistics from 'ee/usage_quotas/storage/components/storage_usage_statistics.vue';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { withRootStorageStatistics, defaultNamespaceProvideValues } from '../mock_data';

Vue.use(VueApollo);

const defaultApolloData = {
  subscription: {
    canAddSeats: false,
    canRenew: false,
    communityPlan: false,
  },
  userActionAccess: { limitedAccessReason: 'RAMP_SUBSCRIPTION' },
};

describe('StorageUsageStatistics', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {}, apolloData = defaultApolloData } = {}) => {
    const queryHandlerMock = jest.fn().mockResolvedValue({
      data: apolloData,
    });
    const mockCustomersDotClient = createMockClient([
      [getSubscriptionPermissionsData, queryHandlerMock],
    ]);
    const mockGitlabClient = createMockClient();
    const mockApollo = new VueApollo({
      defaultClient: mockGitlabClient,
      clients: { customersDotClient: mockCustomersDotClient, gitlabClient: mockGitlabClient },
    });

    wrapper = shallowMountExtended(StorageUsageStatistics, {
      propsData: {
        additionalPurchasedStorageSize: withRootStorageStatistics.additionalPurchasedStorageSize,
        usedStorage: withRootStorageStatistics.rootStorageStatistics.storageSize,
        loading: false,
        ...props,
      },
      provide: {
        ...defaultNamespaceProvideValues,
        ...provide,
      },
      apolloProvider: mockApollo,
      stubs: {
        StorageUsageOverviewCard,
        NumberToHumanSize,
        GlSprintf,
        GlButton,
        GlLink,
        GlProgressBar,
      },
    });
  };

  const findStorageUsageOverviewCard = () => wrapper.findComponent(StorageUsageOverviewCard);
  const findNamespaceLimitsStorageUsageOverviewCard = () =>
    wrapper.findComponent(NamespaceLimitsStorageUsageOverviewCard);
  const findNamespaceLimitsTotalStorageAvailableBreakdownCard = () =>
    wrapper.findComponent(NamespaceLimitsTotalStorageAvailableBreakdownCard);
  const findProjectLimitsExcessStorageBreakdownCard = () =>
    wrapper.findComponent(ProjectLimitsExcessStorageBreakdownCard);
  const findOverviewSubtitle = () => wrapper.findByTestId('overview-subtitle');
  const findPurchaseButton = () => wrapper.findComponent(GlButton);
  const findLimitedAccessModal = () => wrapper.findComponent(LimitedAccessModal);

  describe('namespace overview section', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the namespace storage overview subtitle', () => {
      expect(findOverviewSubtitle().text()).toBe(NAMESPACE_STORAGE_OVERVIEW_SUBTITLE);
    });

    describe('purchase more storage button when namespace is using project enforcement', () => {
      it('does not render the button', () => {
        createComponent();
        expect(findPurchaseButton().exists()).toBe(false);
      });
    });

    describe('purchase more storage button when namespace is NOT using project enforcement', () => {
      describe('when purchaseStorageUrl is provided', () => {
        beforeEach(() => {
          createComponent({
            provide: {
              isUsingProjectEnforcement: false,
            },
          });
        });

        it('renders purchase button with the correct attributes', () => {
          expect(findPurchaseButton().attributes()).toMatchObject({
            href: 'some-fancy-url',
            target: '_blank',
          });
        });

        it('does not show modal on purchase button click', () => {
          findPurchaseButton().vm.$emit('click');

          expect(findLimitedAccessModal().exists()).toBe(false);
        });
      });

      describe('when purchaseStorageUrl is provided and limitedAccessModal FF is on', () => {
        beforeEach(async () => {
          gon.features = { limitedAccessModal: true };
          createComponent({
            provide: {
              isUsingProjectEnforcement: false,
            },
          });

          await waitForPromises();

          findPurchaseButton().vm.$emit('click');
          await nextTick();
        });

        it('shows modal', () => {
          expect(findLimitedAccessModal().isVisible()).toBe(true);
        });
      });

      it('is not rendered if purchaseStorageUrl is not provided', () => {
        createComponent({
          provide: {
            isUsingProjectEnforcement: false,
            purchaseStorageUrl: undefined,
          },
        });

        expect(findPurchaseButton().exists()).toBe(false);
      });
    });

    describe('enforcement type subtitle', () => {
      it('renders project enforcement copy if enforcementType is project', () => {
        expect(wrapper.text()).toContain(
          'Projects under this namespace have 978.8 KiB of storage. How are limits applied?',
        );
      });

      it('renders namespace enforcement copy if enforcementType is namespace', () => {
        // Namespace enforcement type is declared in ee/app/models/namespaces/storage/root_size.rb
        // More about namespace storage limit at https://docs.gitlab.com/ee/user/usage_quotas#namespace-storage-limit
        createComponent({
          provide: {
            isUsingProjectEnforcement: false,
            isUsingNamespaceEnforcement: true,
          },
        });

        expect(wrapper.text()).toContain(
          'This namespace has 978.8 KiB of storage. How are limits applied?',
        );
      });
    });
  });

  describe('StorageStatisticsCard', () => {
    it('passes the correct props to StorageStatisticsCard', () => {
      createComponent();

      expect(findStorageUsageOverviewCard().props()).toEqual({
        usedStorage: withRootStorageStatistics.rootStorageStatistics.storageSize,
        loading: false,
      });
    });

    it('passes the correct props to NamespaceLimitsStorageStatisticsCard', () => {
      createComponent({
        provide: {
          isUsingProjectEnforcement: false,
          isUsingNamespaceEnforcement: true,
        },
      });

      expect(findNamespaceLimitsStorageUsageOverviewCard().props()).toEqual({
        usedStorage: withRootStorageStatistics.rootStorageStatistics.storageSize,
        totalStorage:
          withRootStorageStatistics.actualRepositorySizeLimit +
          withRootStorageStatistics.additionalPurchasedStorageSize,
        loading: false,
      });
    });
  });

  describe('NamespaceLimitsTotalStorageAvailableBreakdownCard', () => {
    it('does not render NamespaceLimitsTotalStorageAvailableBreakdownCard when namespace is using project enforcement', () => {
      createComponent();
      expect(findNamespaceLimitsTotalStorageAvailableBreakdownCard().exists()).toBe(false);
    });

    it('passes the correct props to NamespaceLimitsTotalStorageAvailableBreakdownCard when namespace is NOT using project enforcement', () => {
      createComponent({
        provide: {
          isUsingProjectEnforcement: false,
        },
      });

      expect(findNamespaceLimitsTotalStorageAvailableBreakdownCard().props()).toEqual({
        includedStorage: withRootStorageStatistics.actualRepositorySizeLimit,
        purchasedStorage: withRootStorageStatistics.additionalPurchasedStorageSize,
        totalStorage:
          withRootStorageStatistics.actualRepositorySizeLimit +
          withRootStorageStatistics.additionalPurchasedStorageSize,
        loading: false,
      });
    });

    it('does not render storage card if there is no plan information', () => {
      createComponent({
        provide: {
          namespacePlanName: null,
        },
      });

      expect(findNamespaceLimitsTotalStorageAvailableBreakdownCard().exists()).toBe(false);
    });
  });

  describe('ProjectLimitsExcessStorageBreakdownCard', () => {
    it('does not render ProjectLimitsExcessStorageBreakdownCard when namespace is NOT using project enforcement', () => {
      createComponent({
        provide: {
          isUsingProjectEnforcement: false,
        },
      });
      expect(findProjectLimitsExcessStorageBreakdownCard().exists()).toBe(false);
    });

    it('passes the correct props to ProjectLimitsExcessStorageBreakdownCard when namespace is using project enforcement', () => {
      createComponent();

      expect(findProjectLimitsExcessStorageBreakdownCard().props()).toEqual({
        purchasedStorage: withRootStorageStatistics.additionalPurchasedStorageSize,
        limitedAccessModeEnabled: false,
        loading: false,
      });
    });

    it('does not render storage card if there is no plan information', () => {
      createComponent({
        provide: {
          namespacePlanName: null,
        },
      });

      expect(findProjectLimitsExcessStorageBreakdownCard().exists()).toBe(false);
    });
  });
});
