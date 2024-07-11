<script>
import { GlDiscreteScatterChart } from '@gitlab/ui/dist/charts';
import { s__ } from '~/locale';
import { durationNanoToMs } from './trace_utils';

export default {
  components: {
    GlDiscreteScatterChart,
  },
  i18n: {
    yAxisTitle: s__('Tracing|Duration (ms)'),
    xAxisTitle: s__('Tracing|Time range'),
    noDataText: s__('Tracing|No traces to display.'),
    noDataSubtext: s__('Tracing|Check again'),
  },
  props: {
    traces: {
      type: Array,
      required: true,
    },
    height: {
      type: Number,
      required: true,
    },
    rangeMin: {
      type: Date,
      required: false,
      default: () => null,
    },
    rangeMax: {
      type: Date,
      required: false,
      default: () => null,
    },
  },

  computed: {
    chartData() {
      const data = this.traces.map((t) => ({
        value: [t.timestamp, durationNanoToMs(t.duration_nano)],
        traceId: t.trace_id,
        hasError: t.statusCode === 'STATUS_CODE_ERROR',
      }));

      return [
        {
          data,
          type: 'scatter',
          itemStyle: {
            color: (p) => (p.data.hasError ? '#ee6666' : p.color),
          },
          symbol: (_, p) => (p.data.hasError ? 'triangle' : 'circle'),
        },
      ];
    },
    chartOption() {
      const title =
        this.traces.length === 0
          ? {
              text: this.$options.i18n.noDataText,
              subtext: this.$options.i18n.noDataSubtext,
              triggerEvent: true,
              left: 'center',
              top: '40%',
              textStyle: {
                fontSize: 20,
              },
              subtextStyle: {
                fontSize: 15,
                color: '#1f75cb',
              },
            }
          : undefined;
      return {
        title,
        xAxis: {
          type: 'time',
          max: this.rangeMax,
          min: this.rangeMin,
          axisLine: {
            show: true,
            lineStyle: {
              color: '#bfbfc3',
            },
          },
        },
      };
    },
  },

  methods: {
    chartItemClicked(e) {
      if (e?.params?.componentType === 'title') {
        this.$emit('reload-data');
      }
      if (e?.params?.data?.traceId) {
        this.$emit('chart-item-selected', { traceId: e.params.data.traceId });
      }
    },
    chartCreated(chart) {
      chart.on('mouseover', (e) => {
        if (e.data?.traceId) {
          this.$emit('chart-item-over', { traceId: e.data.traceId });
        }
      });
      chart.on('mouseout', (e) => {
        if (e.data?.traceId) {
          this.$emit('chart-item-out', { traceId: e.data.traceId });
        }
      });
    },
  },
};
</script>

<template>
  <gl-discrete-scatter-chart
    class="gl-mb-7"
    :option="chartOption"
    :data="chartData"
    :height="height"
    :symbol-size="10"
    disable-tooltip
    :y-axis-title="$options.i18n.yAxisTitle"
    :x-axis-title="$options.i18n.xAxisTitle"
    @created="chartCreated"
    @chartItemClicked="chartItemClicked"
  />
</template>
