<script>
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  dateAtFirstDayOfMonth,
  nMonthsBefore,
} from '~/lib/utils/datetime/date_calculation_utility';

import getGroupCurrentAndPrevProductAnalyticsUsageQuery from '../../graphql/queries/get_group_current_and_prev_product_analytics_usage.query.graphql';
import { mapProjectsUsageResponse } from '../../graphql/utils';
import ProductAnalyticsProjectsUsageTable from './product_analytics_projects_usage_table.vue';

export default {
  name: 'ProductAnalyticsProjectsUsage',
  components: {
    GlAlert,
    ProductAnalyticsProjectsUsageTable,
  },
  inject: {
    namespacePath: {
      type: String,
    },
  },
  data() {
    return {
      error: null,
      projectsUsageData: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.projectsUsageData.loading;
    },
  },
  apollo: {
    projectsUsageData: {
      query: getGroupCurrentAndPrevProductAnalyticsUsageQuery,
      variables() {
        const current = dateAtFirstDayOfMonth(new Date());
        const previous = nMonthsBefore(current, 1);

        return {
          namespacePath: this.namespacePath,
          currentYear: current.getFullYear(),
          previousYear: previous.getFullYear(),

          // JS `getMonth()` is 0 based
          currentMonth: current.getMonth() + 1,
          previousMonth: previous.getMonth() + 1,
        };
      },
      update(data) {
        return mapProjectsUsageResponse(data);
      },
      error(error) {
        this.error = error;
        Sentry.captureException(error);
      },
    },
  },
};
</script>
<template>
  <section>
    <h2 class="gl-font-lg">{{ s__('Analytics|Usage by project') }}</h2>
    <gl-alert v-if="error" variant="danger" :dismissible="false">
      {{
        s__(
          'Analytics|Something went wrong while loading product analytics usage data. Refresh the page to try again.',
        )
      }}
    </gl-alert>
    <product-analytics-projects-usage-table
      v-else
      :is-loading="isLoading"
      :projects-usage-data="projectsUsageData"
    />
  </section>
</template>
