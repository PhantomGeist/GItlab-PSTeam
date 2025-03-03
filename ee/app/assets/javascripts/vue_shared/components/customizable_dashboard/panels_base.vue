<script>
import {
  GlDisclosureDropdown,
  GlIcon,
  GlLink,
  GlLoadingIcon,
  GlPopover,
  GlSprintf,
  GlButton,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import uniqueId from 'lodash/uniqueId';
import isString from 'lodash/isString';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import dataSources from 'ee/analytics/analytics_dashboards/data_sources';
import { isEmptyPanelData } from 'ee/vue_shared/components/customizable_dashboard/utils';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import { HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import { __, s__ } from '~/locale';
import { PANEL_POPOVER_DELAY, PANEL_TROUBLESHOOTING_URL } from './constants';

export default {
  name: 'AnalyticsDashboardPanel',
  components: {
    GlDisclosureDropdownItem,
    GlDisclosureDropdown,
    GlIcon,
    GlLink,
    GlLoadingIcon,
    GlPopover,
    GlSprintf,
    GlButton,
    TooltipOnTruncate,
    LineChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/line_chart.vue'),
    ColumnChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/column_chart.vue'),
    DataTable: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/data_table.vue'),
    SingleStat: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/single_stat.vue'),
    DORAChart: () =>
      import('ee/analytics/analytics_dashboards/components/visualizations/dora_chart.vue'),
  },
  inject: ['namespaceId', 'namespaceFullPath', 'namespaceName', 'isProject'],
  props: {
    visualization: {
      type: Object,
      required: true,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    queryOverrides: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    editing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    const validationErrors = this.visualization?.errors;

    return {
      errors: validationErrors || [],
      hasValidationErrors: Boolean(validationErrors),
      canRetryError: false,
      data: null,
      loading: false,
      popoverId: uniqueId('panel-error-popover-'),
      dropdownItems: [
        {
          text: __('Delete'),
          action: () => this.$emit('delete'),
          icon: 'remove',
        },
      ],
    };
  },
  computed: {
    showEmptyState() {
      return !this.showErrorState && isEmptyPanelData(this.visualization.type, this.data);
    },
    showErrorState() {
      return this.errors.length > 0;
    },
    errorMessages() {
      return this.errors.filter(isString);
    },
    errorPopoverTitle() {
      return this.hasValidationErrors
        ? s__('Analytics|Invalid visualization configuration')
        : s__('Analytics|Failed to fetch data');
    },
    errorPopoverMessage() {
      return this.hasValidationErrors
        ? s__(
            'Analytics|Something is wrong with your panel visualization configuration. See %{linkStart}troubleshooting documentation%{linkEnd}.',
          )
        : s__(
            'Analytics|Something went wrong while connecting to your data source. See %{linkStart}troubleshooting documentation%{linkEnd}.',
          );
    },
    namespace() {
      return {
        name: this.namespaceName,
        requestPath: this.namespaceFullPath,
        isProject: this.isProject,
      };
    },
  },
  watch: {
    visualization: {
      handler: 'fetchData',
      immediate: true,
    },
    queryOverrides: 'fetchData',
    filters: 'fetchData',
  },
  methods: {
    async fetchData() {
      if (this.hasValidationErrors) {
        return;
      }

      const { queryOverrides, filters } = this;
      const { type: dataType, query } = this.visualization.data;
      this.loading = true;
      this.errors = [];

      try {
        const { fetch } = await dataSources[dataType]();
        this.data = await fetch({
          title: this.title,
          projectId: this.namespaceId,
          namespace: this.namespace,
          query,
          queryOverrides,
          visualizationType: this.visualization.type,
          visualizationOptions: this.visualization.options,
          filters,
        });
      } catch (error) {
        this.handleFetchError(error);
      } finally {
        this.loading = false;
      }
    },
    handleFetchError(error) {
      const isCubeJsBadRequest = this.isCubeJsBadRequest(error);
      this.canRetryError = !isCubeJsBadRequest; // bad or malformed CubeJS query, retry won't fix

      this.errors = [error];

      Sentry.captureException(error);
    },
    isCubeJsBadRequest(error) {
      return Boolean(error.status === HTTP_STATUS_BAD_REQUEST && error.response?.message);
    },
  },
  PANEL_POPOVER_DELAY,
  PANEL_TROUBLESHOOTING_URL,
};
</script>

<template>
  <div
    :id="popoverId"
    class="grid-stack-item-content gl-border gl-rounded-small gl-p-4 gl-display-flex gl-flex-direction-column gl-bg-white gl-overflow-visible!"
    :class="{
      'gl-border-t-2 gl-border-t-solid gl-border-t-red-500': showErrorState,
    }"
  >
    <div class="gl-display-flex gl-align-items-flex-start gl-justify-content-space-between">
      <tooltip-on-truncate
        v-if="title"
        :title="title"
        placement="top"
        boundary="viewport"
        class="gl-pb-3 gl-text-truncate"
      >
        <gl-icon v-if="showErrorState" name="warning" class="gl-text-red-500 gl-mr-1" />
        <strong class="gl-text-gray-700">{{ title }}</strong>
      </tooltip-on-truncate>
      <gl-disclosure-dropdown
        v-if="editing"
        :items="dropdownItems"
        icon="ellipsis_v"
        :toggle-text="__('Actions')"
        text-sr-only
        no-caret
        placement="right"
        fluid-width
        toggle-class="gl-ml-1"
        category="tertiary"
      >
        <template #list-item="{ item }">
          <span :data-testId="`panel-action-${item.testId}`">
            <gl-icon :name="item.icon" /> {{ item.text }}</span
          >
        </template>
      </gl-disclosure-dropdown>
    </div>
    <div
      class="gl-overflow-x-hidden gl-overflow-y-auto gl-h-full"
      :class="{ 'gl--flex-center': loading }"
    >
      <gl-loading-icon v-if="loading" size="lg" />

      <div v-else-if="showEmptyState" class="gl-text-secondary">
        {{ s__('Analytics|No results match your query or filter.') }}
      </div>

      <div v-else-if="showErrorState" class="gl-text-secondary">
        {{ s__('Analytics|Something went wrong.') }}
      </div>

      <component :is="visualization.type" v-else :data="data" :options="visualization.options" />
    </div>

    <gl-popover
      v-if="showErrorState"
      triggers="hover focus"
      :title="errorPopoverTitle"
      :show-close-button="false"
      placement="top"
      :css-classes="['gl-max-w-50p']"
      :target="popoverId"
      :delay="$options.PANEL_POPOVER_DELAY"
    >
      <gl-sprintf :message="errorPopoverMessage">
        <template #link="{ content }">
          <gl-link :href="$options.PANEL_TROUBLESHOOTING_URL" class="gl-font-sm">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
      <ul v-if="errorMessages.length">
        <li v-for="errorMessage in errorMessages" :key="errorMessage">
          {{ errorMessage }}
        </li>
      </ul>
      <gl-button v-if="canRetryError" class="gl-display-block gl-mt-3" @click="fetchData">{{
        __('Retry')
      }}</gl-button>
    </gl-popover>
  </div>
</template>
