import { withVuexStore } from 'storybook_addons/vuex_store';
import DurationOverviewChart from './duration_overview_chart.vue';
import { durationChartData } from './stories_constants';

export default {
  component: DurationOverviewChart,
  title: 'ee/analytics/cycle_analytics/components/duration_overview_chart',
  decorators: [withVuexStore],
};

const Template = (args, { argTypes, createVuexStore }) => ({
  components: { DurationOverviewChart },
  props: Object.keys(argTypes),
  template: '<duration-overview-chart v-bind="$props" />',
  store: createVuexStore({
    modules: {
      durationChart: {
        namespaced: true,
        getters: {
          durationOverviewChartPlottableData: () => durationChartData,
        },
        state: {
          isLoading: false,
        },
      },
    },
  }),
});

export const Default = Template.bind({});
