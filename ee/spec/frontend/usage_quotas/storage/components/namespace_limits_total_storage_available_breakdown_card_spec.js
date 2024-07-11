import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NamespaceLimitsTotalStorageAvailableBreakdownCard from 'ee/usage_quotas/storage/components/namespace_limits_total_storage_available_breakdown_card.vue';
import NumberToHumanSize from 'ee/usage_quotas/storage/components/number_to_human_size.vue';
import { withRootStorageStatistics, defaultNamespaceProvideValues } from '../mock_data';

describe('NamespaceLimitsTotalStorageAvailableBreakdownCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(NamespaceLimitsTotalStorageAvailableBreakdownCard, {
      propsData: {
        includedStorage: withRootStorageStatistics.actualRepositorySizeLimit,
        purchasedStorage: withRootStorageStatistics.additionalPurchasedStorageSize,
        totalStorage:
          withRootStorageStatistics.actualRepositorySizeLimit +
          withRootStorageStatistics.additionalPurchasedStorageSize,
        loading: false,
        ...props,
      },
      provide: {
        ...defaultNamespaceProvideValues,
        isUsingProjectEnforcement: false,
        ...provide,
      },
      stubs: {
        NumberToHumanSize,
      },
    });
  };

  const findStorageIncludedInPlan = () => wrapper.findByTestId('storage-included-in-plan');
  const findStoragePurchased = () => wrapper.findByTestId('storage-purchased');
  const findTotalStorage = () => wrapper.findByTestId('total-storage');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  beforeEach(() => {
    createComponent();
  });

  it('renders storage included in the plan', () => {
    expect(findStorageIncludedInPlan().text()).toContain('978.8 KiB');
  });

  it('renders plan storage description', () => {
    expect(wrapper.text()).toContain('Included in Free subscription');
  });

  it('renders purchased storage', () => {
    expect(findStoragePurchased().text()).toContain('321 B');
  });

  it('renders total storage', () => {
    expect(findTotalStorage().text()).toContain('979.1 KiB');
  });

  describe('skeleton loader', () => {
    it('renders skeleton loader when loading prop is true', () => {
      createComponent({ props: { loading: true } });
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render skeleton loader when loading prop is false', () => {
      createComponent({ props: { loading: false } });
      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });
});
