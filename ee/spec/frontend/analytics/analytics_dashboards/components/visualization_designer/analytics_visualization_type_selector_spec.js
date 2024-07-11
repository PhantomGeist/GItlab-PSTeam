import { GlDropdown, GlDropdownItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AnalyticsVisualizationTypeSelector from 'ee/analytics/analytics_dashboards/components/visualization_designer/analytics_visualization_type_selector.vue';

describe('AnalyticsVisualizationTypeSelector', () => {
  let wrapper;

  const createWrapper = (selectedVisualizationType = '', state = null) => {
    wrapper = shallowMountExtended(AnalyticsVisualizationTypeSelector, {
      propsData: {
        selectedVisualizationType,
        state,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDropdown);
  const findDropdownItemByText = (text) =>
    wrapper.findAllComponents(GlDropdownItem).wrappers.find((w) => w.text() === text);

  it('displays the placeholder content when no type is selected', () => {
    createWrapper();

    expect(findDropdown().props()).toMatchObject({
      text: 'Select a visualization type',
      icon: null,
    });
  });

  it.each`
    type             | icon       | text
    ${'LineChart'}   | ${'chart'} | ${'Line chart'}
    ${'ColumnChart'} | ${'chart'} | ${'Column chart'}
    ${'DataTable'}   | ${'table'} | ${'Data table'}
    ${'SingleStat'}  | ${'table'} | ${'Single statistic'}
  `('selects the option "$text" when the type is "$type"', ({ icon, type, text }) => {
    createWrapper(type);

    expect(findDropdown().props()).toMatchObject({ text, icon });

    const item = findDropdownItemByText(text);

    expect(item.props('iconName')).toBe(icon);

    item.vm.$emit('click');

    expect(wrapper.emitted('selectVisualizationType')[0]).toStrictEqual([type]);
  });
});
