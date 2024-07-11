import { GlDaterangePicker, GlDropdown, GlDropdownItem, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import DateRangeFilter from 'ee/vue_shared/components/customizable_dashboard/filters/date_range_filter.vue';
import {
  DATE_RANGE_OPTIONS,
  DEFAULT_SELECTED_OPTION_INDEX,
  TODAY,
} from 'ee/vue_shared/components/customizable_dashboard/filters/constants';
import { dateRangeOptionToFilter } from 'ee/vue_shared/components/customizable_dashboard/utils';

describe('DateRangeFilter', () => {
  let wrapper;

  const dateRangeOptionIndex = DATE_RANGE_OPTIONS.findIndex(
    (option) => !option.showDateRangePicker,
  );
  const customRangeOptionIndex = DATE_RANGE_OPTIONS.findIndex(
    (option) => option.showDateRangePicker,
  );

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(DateRangeFilter, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        ...props,
      },
    });
  };

  const findDateRangePicker = () => wrapper.findComponent(GlDaterangePicker);
  const findDropdown = () => wrapper.findComponent(GlDropdown);
  const findDropdownItems = () => wrapper.findAllComponents(GlDropdownItem);
  const findHelpIcon = () => wrapper.findComponent(GlIcon);

  describe('default behaviour', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders a dropdown with the text set to the default selected option', () => {
      expect(findDropdown().props().text).toBe(
        DATE_RANGE_OPTIONS[DEFAULT_SELECTED_OPTION_INDEX].text,
      );
    });

    it('renders a dropdown item for each option', () => {
      DATE_RANGE_OPTIONS.forEach((option, idx) => {
        expect(findDropdownItems().at(idx).text()).toBe(option.text);
      });
    });

    it('emits the selected date range when a dropdown item with a date range is clicked', () => {
      findDropdownItems().at(dateRangeOptionIndex).vm.$emit('click');

      expect(wrapper.emitted('change')).toStrictEqual([
        [dateRangeOptionToFilter(DATE_RANGE_OPTIONS[dateRangeOptionIndex])],
      ]);
    });

    it('should show an icon with a tooltip explaining dates are in UTC', () => {
      const helpIcon = findHelpIcon();
      const tooltip = getBinding(helpIcon.element, 'gl-tooltip');

      expect(helpIcon.props('name')).toBe('information-o');
      expect(helpIcon.attributes('title')).toBe(
        'Dates and times are displayed in the UTC timezone',
      );
      expect(tooltip).toBeDefined();
    });
  });

  describe('with a default option', () => {
    const customOption = DATE_RANGE_OPTIONS[customRangeOptionIndex];

    beforeEach(() => {
      createWrapper({ defaultOption: customOption.key });
    });

    it('selects the provided default option', () => {
      expect(findDropdown().props().text).toBe(customOption.text);
    });
  });

  describe('date range picker', () => {
    describe('by default', () => {
      const { startDate, endDate } = DATE_RANGE_OPTIONS[DEFAULT_SELECTED_OPTION_INDEX];

      beforeEach(() => {
        createWrapper({ startDate, endDate });
      });

      it('does not emit a new date range when the option shows the date range picker', async () => {
        await findDropdownItems().at(customRangeOptionIndex).vm.$emit('click');

        expect(wrapper.emitted('change')).toBeUndefined();
      });

      it('shows the date range picker with the provided date range when the option enables it', async () => {
        expect(findDateRangePicker().exists()).toBe(false);

        await findDropdownItems().at(customRangeOptionIndex).vm.$emit('click');

        expect(findDateRangePicker().props()).toMatchObject({
          toLabel: 'To',
          fromLabel: 'From',
          tooltip: null,
          defaultMaxDate: TODAY,
          maxDateRange: 0,
          value: {
            startDate,
            endDate,
          },
          defaultStartDate: startDate,
          defaultEndDate: endDate,
        });
      });
    });

    describe.each([
      { dateRangeLimit: 0, expectedTooltip: null },
      { dateRangeLimit: 1, expectedTooltip: 'Date range limited to 1 day' },
      { dateRangeLimit: 12, expectedTooltip: 'Date range limited to 12 days' },
      { dateRangeLimit: 31, expectedTooltip: 'Date range limited to 31 days' },
    ])(
      'when given a date range limit of $dateRangeLimit',
      ({ dateRangeLimit, expectedTooltip }) => {
        beforeEach(() => {
          createWrapper({ dateRangeLimit });
        });

        it('shows the date range picker with date range limit applied', async () => {
          expect(findDateRangePicker().exists()).toBe(false);

          await findDropdownItems().at(customRangeOptionIndex).vm.$emit('click');

          expect(findDateRangePicker().props()).toMatchObject({
            tooltip: expectedTooltip,
            maxDateRange: dateRangeLimit,
          });
        });
      },
    );
  });
});
