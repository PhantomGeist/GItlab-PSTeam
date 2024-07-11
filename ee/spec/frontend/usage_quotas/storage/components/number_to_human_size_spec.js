import { shallowMount } from '@vue/test-utils';
import NumberToHumanSize from 'ee/usage_quotas/storage/components/number_to_human_size.vue';
import { numberToHumanSize } from '~/lib/utils/number_utils';

describe('NumberToHumanSize', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(NumberToHumanSize, {
      propsData: {
        ...props,
      },
    });
  };

  it('formats the value', () => {
    const value = 1024;
    createComponent({ value });

    const expectedValue = numberToHumanSize(value, 1);
    expect(wrapper.text()).toBe(expectedValue);
  });

  it('handles number of fraction digits', () => {
    const value = 1024 + 254;
    const fractionDigits = 2;
    createComponent({ value, fractionDigits });

    const expectedValue = numberToHumanSize(value, fractionDigits);
    expect(wrapper.text()).toBe(expectedValue);
  });

  describe('plain-zero', () => {
    it('hides label for zero values', () => {
      createComponent({ value: 0, plainZero: true });
      expect(wrapper.text()).toBe('0');
    });

    it('shows text for non-zero values', () => {
      const value = 163;
      const expectedValue = numberToHumanSize(value, 1);
      createComponent({ value, plainZero: true });
      expect(wrapper.text()).toBe(expectedValue);
    });
  });
});
