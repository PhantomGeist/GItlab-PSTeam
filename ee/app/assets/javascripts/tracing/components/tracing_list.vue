<script>
import { GlLoadingIcon, GlInfiniteScroll } from '@gitlab/ui';
import { debounce } from 'lodash';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { visitUrl, joinPaths } from '~/lib/utils/url_utility';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { contentTop, isMetaClick } from '~/lib/utils/common_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import {
  queryToFilterObj,
  filterObjToQuery,
  filterObjToFilterToken,
  filterTokensToFilterObj,
} from '../filters';
import TracingTableList from './tracing_table_list.vue';
import FilteredSearch from './tracing_list_filtered_search.vue';
import ScatterChart from './tracing_scatter_chart.vue';
import { periodFilterToDate } from './trace_utils';

const PAGE_SIZE = 500;
const CHART_HEIGHT = 300;
const TRACING_LIST_VERTICAL_PADDING = 120; // Accounts for the search bar height + the legend height + some more v padding

export default {
  components: {
    GlLoadingIcon,
    TracingTableList,
    FilteredSearch,
    UrlSync,
    GlInfiniteScroll,
    ScatterChart,
  },
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      loading: false,
      traces: [],
      filters: queryToFilterObj(window.location.search),
      nextPageToken: null,
      chartRangeMin: null,
      chartRangeMax: null,
      highlightedTraceId: null,
    };
  },
  computed: {
    query() {
      return filterObjToQuery(this.filters);
    },
    initialFilterValue() {
      return filterObjToFilterToken(this.filters);
    },
    infiniteScrollLegend() {
      if (this.traces.length > 0) return s__(`Tracing|Showing ${this.traces.length} traces`);
      return null;
    },
    listHeight() {
      return window.innerHeight - contentTop() - TRACING_LIST_VERTICAL_PADDING - CHART_HEIGHT;
    },
  },
  created() {
    this.debouncedChartItemOver = debounce(this.chartItemOver, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    this.fetchTraces();
  },
  methods: {
    async fetchTraces({ skipUpdatingChartRange = false } = {}) {
      this.loading = true;

      try {
        const {
          traces,
          next_page_token: nextPageToken,
        } = await this.observabilityClient.fetchTraces({
          filters: this.filters,
          pageToken: this.nextPageToken,
          pageSize: PAGE_SIZE,
        });
        if (!skipUpdatingChartRange) {
          const { min, max } = periodFilterToDate(this.filters);
          this.chartRangeMax = max;
          this.chartRangeMin = min;
        }

        this.traces = [...this.traces, ...traces];
        if (nextPageToken) {
          this.nextPageToken = nextPageToken;
        }
      } catch (e) {
        createAlert({
          message: s__('Tracing|Failed to load traces.'),
        });
      } finally {
        this.loading = false;
      }
    },
    onTraceClicked({ traceId, clickEvent = {} }) {
      const external = isMetaClick(clickEvent);
      visitUrl(joinPaths(window.location.pathname, traceId), external);
    },
    handleFilters(filterTokens) {
      this.filters = filterTokensToFilterObj(filterTokens);
      this.nextPageToken = null;
      this.traces = [];
      this.fetchTraces();
    },
    bottomReached() {
      this.fetchTraces({ skipUpdatingChartRange: true });
    },
    chartItemSelected({ traceId }) {
      this.onTraceClicked({ traceId });
    },
    chartItemOver({ traceId }) {
      const index = this.traces.findIndex((x) => x.trace_id === traceId);
      if (index >= 0) {
        this.highlightedTraceId = traceId;
        this.scrollToRow(index);
      }
    },
    scrollToRow(index) {
      const tbody = this.$refs.tableList.$el.querySelector('tbody');
      const row = tbody.querySelectorAll('tr')[index];
      if (row) {
        this.$refs.infiniteScroll.scrollTo({ top: row.offsetTop, behavior: 'smooth' });
      }
    },
    chartItemOut() {
      this.highlightedTraceId = null;
    },
  },
  CHART_HEIGHT,
};
</script>

<template>
  <div>
    <div v-if="loading && traces.length === 0" class="gl-py-5">
      <gl-loading-icon size="lg" />
    </div>

    <template v-else>
      <url-sync :query="query" />
      <filtered-search
        :initial-filters="initialFilterValue"
        :observability-client="observabilityClient"
        @submit="handleFilters"
      />
      <scatter-chart
        :height="$options.CHART_HEIGHT"
        :range-min="chartRangeMin"
        :range-max="chartRangeMax"
        :traces="traces"
        @chart-item-selected="chartItemSelected"
        @chart-item-over="debouncedChartItemOver"
        @chart-item-out="chartItemOut"
        @reload-data="fetchTraces"
      />

      <gl-infinite-scroll
        ref="infiniteScroll"
        :max-list-height="listHeight"
        :fetched-items="traces.length"
        @bottomReached="bottomReached"
      >
        <template #items>
          <tracing-table-list
            ref="tableList"
            :traces="traces"
            :highlighted-trace-id="highlightedTraceId"
            @reload="fetchTraces"
            @trace-clicked="onTraceClicked"
          />
        </template>

        <template #default>
          <gl-loading-icon v-if="loading" size="md" />
          <span v-else data-testid="tracing-infinite-scrolling-legend">{{
            infiniteScrollLegend
          }}</span>
        </template>
      </gl-infinite-scroll>
    </template>
  </div>
</template>
