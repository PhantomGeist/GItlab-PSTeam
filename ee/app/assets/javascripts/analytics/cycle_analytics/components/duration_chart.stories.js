import { withVuexStore } from 'storybook_addons/vuex_store';
import DurationChart from './duration_chart.vue';
import { selectedStageData, selectedStage } from './stories_constants';

export default {
  component: DurationChart,
  title: 'ee/analytics/cycle_analytics/components/duration_chart',
  decorators: [withVuexStore],
};

const Template = (args, { argTypes, createVuexStore }) => ({
  components: { DurationChart },
  props: Object.keys(argTypes),
  template: '<duration-chart v-bind="$props" />',
  store: createVuexStore({
    state: {
      selectedStage,
    },
    modules: {
      durationChart: {
        namespaced: true,
        getters: {
          durationChartPlottableData: () => selectedStageData,
        },
        state: {
          isLoading: false,
        },
      },
    },
  }),
});

export const Default = Template.bind({});
