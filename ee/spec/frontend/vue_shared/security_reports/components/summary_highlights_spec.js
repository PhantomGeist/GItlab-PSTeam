import { GlSprintf } from '@gitlab/ui';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('MR Widget Security Reports - Summary Highlights', () => {
  let wrapper;

  const createComponent = ({ highlights, showSingleSeverity } = {}) => {
    wrapper = shallowMountExtended(SummaryHighlights, {
      propsData: {
        highlights,
        showSingleSeverity,
      },
      stubs: { GlSprintf },
    });
  };

  it('should display the summary highlights properly', () => {
    createComponent({
      highlights: {
        critical: 10,
        high: 20,
        other: 60,
      },
    });

    expect(wrapper.html()).toMatchSnapshot();
  });

  it("calculate 'others' when other severities are provided", () => {
    const others = { medium: 50, low: 30, unknown: 20 };

    createComponent({
      highlights: {
        critical: 10,
        high: 20,
        ...others,
      },
    });

    expect(wrapper.text()).toContain('100 others');
  });

  it.each`
    severity      | color                   | count
    ${'critical'} | ${'gl-text-red-800'}    | ${10}
    ${'high'}     | ${'gl-text-red-600'}    | ${20}
    ${'medium'}   | ${'gl-text-orange-400'} | ${50}
    ${'low'}      | ${'gl-text-orange-300'} | ${30}
    ${'unknown'}  | ${'gl-text-gray-400'}   | ${20}
  `(
    "displays a number only when 'showSingleSeverity' property is provided",
    ({ severity, color, count }) => {
      const others = { medium: 50, low: 30, unknown: 20 };

      createComponent({
        showSingleSeverity: severity,
        highlights: {
          critical: 10,
          high: 20,
          ...others,
        },
      });

      expect(wrapper.html()).toContain(color);
      expect(wrapper.text()).toBe(count.toString());
    },
  );
});
