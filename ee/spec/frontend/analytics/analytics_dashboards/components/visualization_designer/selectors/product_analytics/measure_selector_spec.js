import { nextTick } from 'vue';
import { GlLabel } from '@gitlab/ui';
import {
  EVENTS_TABLE_NAME,
  SESSIONS_TABLE_NAME,
} from 'ee/analytics/analytics_dashboards/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProductAnalyticsMeasureSelector from 'ee/analytics/analytics_dashboards/components/visualization_designer/selectors/product_analytics/measure_selector.vue';

describe('ProductAnalyticsMeasureSelector', () => {
  let wrapper;

  const findMeasureSummary = () => wrapper.findByTestId('measure-summary');
  const findBackButton = () => wrapper.findByTestId('measure-back-button');
  const findAllEventsButton = (testId) => wrapper.findByTestId(testId);
  const getLabelTitle = () => wrapper.findComponent(GlLabel).props('title');

  const setMeasures = jest.fn();
  const setFilters = jest.fn();
  const addFilters = jest.fn();

  const createWrapper = () => {
    wrapper = shallowMountExtended(ProductAnalyticsMeasureSelector, {
      propsData: {
        measures: [],
        setMeasures,
        filters: [],
        setFilters,
        addFilters,
      },
    });
  };

  const navigateToSubPage = async (startbutton) => {
    const overvViewButton = wrapper.findByTestId(startbutton);

    // Overview
    overvViewButton.vm.$emit('click');

    await nextTick();

    // Detail selection checks
    expect(wrapper.findByTestId(startbutton).exists()).toBe(false);
  };

  const checkFinalStep = async (measureFieldName, summaryString) => {
    await nextTick();

    expect(setMeasures).toHaveBeenCalledWith([measureFieldName]);

    expect(findMeasureSummary().exists()).toBe(true);
    expect(getLabelTitle()).toContain(summaryString);
  };

  describe('when mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should not render back button on overview', () => {
      expect(findBackButton().exists()).toBe(false);
    });

    it('backbutton fires a setMeasure correctly', async () => {
      const overvViewButton = wrapper.findByTestId('pageviews-button');

      overvViewButton.vm.$emit('click');

      await nextTick();

      findBackButton().vm.$emit('click');

      expect(setMeasures).toHaveBeenCalledWith([]);
      expect(setFilters).toHaveBeenCalledWith([]);
    });

    it('renders the column title', () => {
      expect(wrapper.text()).toContain('What metric do you want to visualize?');
    });
  });

  it.each`
    startButton                 | showAllButton                   | eventType       | field                | summaryString
    ${'linkclickevents-button'} | ${'linkclickevents-all-button'} | ${'link_click'} | ${'linkClicksCount'} | ${'linkClickEvents::all'}
    ${'events-button'}          | ${'events-all-button'}          | ${''}           | ${'count'}           | ${'events::all'}
  `(
    'navigates from overview to event subpage $summaryString',
    async ({ startButton, showAllButton, eventType, field, summaryString }) => {
      createWrapper();

      await navigateToSubPage(startButton);

      const showAllEventsButton = findAllEventsButton(showAllButton);
      expect(showAllEventsButton.exists()).toBe(true);
      expect(findBackButton().exists()).toBe(true);

      showAllEventsButton.vm.$emit('click');

      const summarySubValues = summaryString.split('::');
      expect(wrapper.emitted('measureSelected')).toEqual([[summarySubValues[0]], summarySubValues]);

      await checkFinalStep(`${EVENTS_TABLE_NAME}.${field}`, summaryString);

      if (eventType) {
        expect(addFilters).toHaveBeenCalledWith({
          member: `${EVENTS_TABLE_NAME}.eventName`,
          operator: 'equals',
          values: [eventType],
        });
      }
    },
  );

  it.each`
    startButton           | showAllButton             | summaryString
    ${'pageviews-button'} | ${'pageviews-all-button'} | ${'pageViews::all'}
  `(
    'navigates from overview to event subpage $summaryString',
    async ({ startButton, showAllButton, summaryString }) => {
      createWrapper();

      await navigateToSubPage(startButton);

      const showAllEventsButton = findAllEventsButton(showAllButton);

      expect(showAllEventsButton.exists()).toBe(true);
      expect(findBackButton().exists()).toBe(true);

      showAllEventsButton.vm.$emit('click');

      const summarySubValues = summaryString.split('::');
      expect(wrapper.emitted('measureSelected')).toEqual([[summarySubValues[0]], summarySubValues]);

      await checkFinalStep(`${EVENTS_TABLE_NAME}.pageViewsCount`, summaryString);
    },
  );

  it.each`
    startButton       | summaryString
    ${'users-button'} | ${'uniqueUsers::all'}
  `(
    'navigates from overview to users subpage $summaryString',
    async ({ startButton, summaryString }) => {
      createWrapper();

      await navigateToSubPage(startButton);

      const summarySubValues = summaryString.split('::');
      expect(wrapper.emitted('measureSelected')).toEqual([
        [summarySubValues[0], summarySubValues[1]],
      ]);

      await checkFinalStep(`${EVENTS_TABLE_NAME}.uniqueUsersCount`, summaryString);
    },
  );

  it.each`
    startButton                      | measureName                 | summaryString
    ${'sessions-count-button'}       | ${'count'}                  | ${'sessions::count'}
    ${'sessions-avgduration-button'} | ${'averageDurationMinutes'} | ${'sessions::averageDurationMinutes'}
    ${'sessions-avgperuser-button'}  | ${'averagePerUser'}         | ${'sessions::averagePerUser'}
    ${'sessions-repeat-button'}      | ${'repeatPercent'}          | ${'sessions::repeatPercent'}
  `(
    'navigates from overview to sessions subpage $measureName',
    async ({ startButton, measureName, summaryString }) => {
      createWrapper();

      const summarySubValues = summaryString.split('::');

      // Overview
      wrapper.findByTestId('sessions-button').vm.$emit('click');

      await nextTick();

      const selectTypeButton = wrapper.findByTestId(startButton);
      expect(selectTypeButton.exists()).toBe(true);
      expect(findBackButton().exists()).toBe(true);

      selectTypeButton.vm.$emit('click');

      expect(wrapper.emitted('measureSelected')).toEqual([[summarySubValues[0]], summarySubValues]);

      await checkFinalStep(`${SESSIONS_TABLE_NAME}.${measureName}`, summaryString);
    },
  );
});
