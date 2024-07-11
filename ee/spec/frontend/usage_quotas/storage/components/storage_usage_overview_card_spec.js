import { GlSkeletonLoader } from '@gitlab/ui';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import StorageUsageOverviewCard from 'ee/usage_quotas/storage/components/storage_usage_overview_card.vue';
import NumberToHumanSize from 'ee/usage_quotas/storage/components/number_to_human_size.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { statisticsCardDefaultProps, defaultNamespaceProvideValues } from '../mock_data';

describe('StorageUsageOverviewCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const defaultProps = statisticsCardDefaultProps;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(StorageUsageOverviewCard, {
      propsData: { ...defaultProps, ...props },
      provide: {
        ...defaultNamespaceProvideValues,
        ...provide,
      },
      stubs: {
        NumberToHumanSize,
      },
    });
  };

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  it('displays the used storage value', () => {
    createComponent();
    expect(wrapper.text()).toContain(numberToHumanSize(statisticsCardDefaultProps.usedStorage, 1));
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
