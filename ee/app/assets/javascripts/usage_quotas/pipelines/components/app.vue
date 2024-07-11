<script>
import {
  GlAlert,
  GlButton,
  GlLoadingIcon,
  GlFormGroup,
  GlCollapsibleListbox,
  GlModalDirective,
  GlSprintf,
} from '@gitlab/ui';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { sprintf } from '~/locale';
import { formatDate, getMonthNames } from '~/lib/utils/datetime_utility';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { captureException } from '~/ci/runner/sentry_utils';
import { pushEECproductAddToCartEvent } from 'ee/google_tag_manager';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';
import getCiMinutesUsageNamespace from '../graphql/queries/ci_minutes.query.graphql';
import getCiMinutesUsageNamespaceProjects from '../graphql/queries/ci_minutes_projects.query.graphql';
import {
  ERROR_MESSAGE,
  LABEL_BUY_ADDITIONAL_MINUTES,
  TITLE_USAGE_SINCE,
  TOTAL_USED_UNLIMITED,
  MINUTES_USED,
  ADDITIONAL_MINUTES,
  PERCENTAGE_USED,
  ADDITIONAL_MINUTES_HELP_LINK,
  CI_MINUTES_HELP_LINK,
  CI_MINUTES_HELP_LINK_LABEL,
} from '../constants';
import { USAGE_BY_MONTH_HEADER, USAGE_BY_PROJECT_HEADER } from '../../constants';
import { getUsageDataByYearAsArray, formatIso8601Date } from '../utils';
import LimitedAccessModal from '../../components/limited_access_modal.vue';
import ProjectList from './project_list.vue';
import UsageOverview from './usage_overview.vue';
import MinutesUsagePerMonth from './minutes_usage_per_month.vue';
import MinutesUsagePerProject from './minutes_usage_per_project.vue';

export default {
  name: 'PipelineUsageApp',
  components: {
    GlAlert,
    GlButton,
    GlLoadingIcon,
    GlFormGroup,
    GlSprintf,
    LimitedAccessModal,
    ProjectList,
    UsageOverview,
    MinutesUsagePerProject,
    MinutesUsagePerMonth,
    GlCollapsibleListbox,
  },
  directives: {
    GlModalDirective,
  },
  inject: [
    'pageSize',
    'namespacePath',
    'namespaceId',
    'namespaceActualPlanName',
    'userNamespace',
    'ciMinutesAnyProjectEnabled',
    'ciMinutesDisplayMinutesAvailableData',
    'ciMinutesLastResetDate',
    'ciMinutesMonthlyMinutesLimit',
    'ciMinutesMonthlyMinutesUsed',
    'ciMinutesMonthlyMinutesUsedPercentage',
    'ciMinutesPurchasedMinutesLimit',
    'ciMinutesPurchasedMinutesUsed',
    'ciMinutesPurchasedMinutesUsedPercentage',
    'buyAdditionalMinutesPath',
    'buyAdditionalMinutesTarget',
  ],
  data() {
    const lastResetDate = new Date(this.ciMinutesLastResetDate);
    const year = lastResetDate.getUTCFullYear();
    const month = lastResetDate.getUTCMonth();

    return {
      error: '',
      namespace: null,
      ciMinutesUsage: [],
      projectsCiMinutesUsage: [],
      selectedYear: year,
      selectedMonth: month, // 0-based month index
      subscriptionPermissions: null,
      isLimitedAccessModalShown: false,
    };
  },
  apollo: {
    ciMinutesUsage: {
      query() {
        return getCiMinutesUsageNamespace;
      },
      variables() {
        return {
          namespaceId: this.userNamespace
            ? null
            : convertToGraphQLId(TYPENAME_GROUP, this.namespaceId),
        };
      },
      update(res) {
        return res?.ciMinutesUsage?.nodes;
      },
      error(error) {
        this.error = ERROR_MESSAGE;
        captureException({ error, component: this.$options.name });
      },
    },
    projectsCiMinutesUsage: {
      query() {
        return getCiMinutesUsageNamespaceProjects;
      },
      variables() {
        return {
          namespaceId: this.userNamespace
            ? null
            : convertToGraphQLId(TYPENAME_GROUP, this.namespaceId),
          first: this.pageSize,
          date: this.selectedDateInIso8601,
        };
      },
      update(res) {
        return res?.ciMinutesUsage?.nodes;
      },
      error(error) {
        this.error = ERROR_MESSAGE;
        captureException({ error, component: this.$options.name });
      },
    },
    subscriptionPermissions: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return {
          namespaceId: parseInt(this.namespaceId, 10),
        };
      },
      skip() {
        return !gon.features?.limitedAccessModal;
      },
      update: (data) => ({
        ...data.subscription,
        reason: data.userActionAccess?.limitedAccessReason,
      }),
    },
  },
  computed: {
    selectedDateInIso8601() {
      return formatIso8601Date(this.selectedYear, this.selectedMonth, 1);
    },
    selectedMonthProjectData() {
      const monthData = this.projectsCiMinutesUsage.find((usage) => {
        return usage.monthIso8601 === this.selectedDateInIso8601;
      });

      return monthData || {};
    },
    projects() {
      return this.selectedMonthProjectData?.projects?.nodes ?? [];
    },
    projectsPageInfo() {
      return this.selectedMonthProjectData?.projects?.pageInfo ?? {};
    },
    shouldShowBuyAdditionalMinutes() {
      return this.buyAdditionalMinutesPath && this.buyAdditionalMinutesTarget;
    },
    isLoadingYearUsageData() {
      return this.$apollo.queries.ciMinutesUsage.loading;
    },
    isLoadingMonthProjectUsageData() {
      return this.$apollo.queries.projectsCiMinutesUsage.loading;
    },
    monthlyUsageTitle() {
      return sprintf(TITLE_USAGE_SINCE, {
        usageSince: formatDate(this.ciMinutesLastResetDate, 'mmm dd, yyyy', true),
      });
    },
    monthlyMinutesUsed() {
      return sprintf(MINUTES_USED, {
        minutesUsed: `${this.ciMinutesMonthlyMinutesUsed} / ${this.ciMinutesMonthlyMinutesLimit}`,
      });
    },
    purchasedMinutesUsed() {
      return sprintf(MINUTES_USED, {
        minutesUsed: `${this.ciMinutesPurchasedMinutesUsed} / ${this.ciMinutesPurchasedMinutesLimit}`,
      });
    },
    shouldShowAdditionalMinutes() {
      return (
        this.ciMinutesDisplayMinutesAvailableData && Number(this.ciMinutesPurchasedMinutesLimit) > 0
      );
    },
    usageDataByYear() {
      return getUsageDataByYearAsArray(this.ciMinutesUsage);
    },
    years() {
      return Object.keys(this.usageDataByYear)
        .map(Number)
        .reverse()
        .map((year) => ({
          text: String(year),
          value: year,
        }));
    },
    months() {
      return getMonthNames().map((month, index) => ({
        text: month,
        value: index,
      }));
    },
    selectedMonthName() {
      return getMonthNames()[this.selectedMonth];
    },
    shouldShowLimitedAccessModal() {
      // NOTE: we're using existing flag for seats `canAddSeats`, to infer
      // whether the additional minutes are expandable.
      const canAddMinutes = this.subscriptionPermissions?.canAddSeats ?? true;

      return (
        !canAddMinutes &&
        gon.features?.limitedAccessModal &&
        LIMITED_ACCESS_KEYS.includes(this.subscriptionPermissions.reason)
      );
    },
  },
  methods: {
    clearError() {
      this.error = '';
    },
    fetchMoreProjects(variables) {
      this.$apollo.queries.projectsCiMinutesUsage.fetchMore({
        variables: {
          namespaceId: this.userNamespace
            ? null
            : convertToGraphQLId(TYPENAME_GROUP, this.namespaceId),
          date: this.selectedDateInIso8601,
          ...variables,
        },
        updateQuery(previousResult, { fetchMoreResult }) {
          return fetchMoreResult;
        },
      });
    },
    trackBuyAdditionalMinutesClick() {
      pushEECproductAddToCartEvent();
    },
    usagePercentage(percentage) {
      let percentageUsed;
      if (this.ciMinutesDisplayMinutesAvailableData) {
        percentageUsed = percentage;
      } else if (this.ciMinutesAnyProjectEnabled) {
        percentageUsed = 0;
      }

      if (percentageUsed) {
        return sprintf(PERCENTAGE_USED, {
          percentageUsed,
        });
      }

      return TOTAL_USED_UNLIMITED;
    },
    showLimitedAccessModal() {
      this.isLimitedAccessModalShown = true;
    },
  },
  LABEL_BUY_ADDITIONAL_MINUTES,
  ADDITIONAL_MINUTES,
  ADDITIONAL_MINUTES_HELP_LINK,
  CI_MINUTES_HELP_LINK,
  CI_MINUTES_HELP_LINK_LABEL,
  USAGE_BY_MONTH_HEADER,
  USAGE_BY_PROJECT_HEADER,
};
</script>

<template>
  <div>
    <gl-loading-icon
      v-if="isLoadingYearUsageData"
      class="gl-mt-5"
      size="lg"
      data-testid="pipelines-overview-loading-indicator"
    />

    <gl-alert v-else-if="error" variant="danger" @dismiss="clearError">
      {{ error }}
    </gl-alert>

    <section v-else>
      <div
        v-if="shouldShowBuyAdditionalMinutes"
        class="gl-display-flex gl-justify-content-end gl-py-3"
      >
        <gl-button
          v-if="!shouldShowLimitedAccessModal"
          :href="buyAdditionalMinutesPath"
          :target="buyAdditionalMinutesTarget"
          :aria-label="$options.LABEL_BUY_ADDITIONAL_MINUTES"
          :data-track-label="namespaceActualPlanName"
          data-testid="buy-compute-minutes"
          data-track-action="click_buy_ci_minutes"
          data-track-property="pipeline_quota_page"
          category="primary"
          variant="confirm"
          class="js-buy-additional-minutes"
          @click="trackBuyAdditionalMinutesClick"
        >
          {{ $options.LABEL_BUY_ADDITIONAL_MINUTES }}
        </gl-button>
        <gl-button
          v-else
          v-gl-modal-directive="'limited-access-modal-id'"
          category="primary"
          variant="confirm"
          class="js-buy-additional-minutes"
          @click="showLimitedAccessModal"
        >
          {{ $options.LABEL_BUY_ADDITIONAL_MINUTES }}
        </gl-button>
        <limited-access-modal
          v-if="shouldShowLimitedAccessModal"
          v-model="isLimitedAccessModalShown"
          :limited-access-reason="subscriptionPermissions.reason"
        />
      </div>
      <usage-overview
        :class="{ 'gl-pt-5': !shouldShowBuyAdditionalMinutes }"
        :minutes-title="monthlyUsageTitle"
        :minutes-used="monthlyMinutesUsed"
        minutes-used-testid-selector="plan-compute-minutes"
        :minutes-used-percentage="usagePercentage(ciMinutesMonthlyMinutesUsedPercentage)"
        :minutes-limit="ciMinutesMonthlyMinutesLimit"
        :help-link-href="$options.CI_MINUTES_HELP_LINK"
        :help-link-label="$options.CI_MINUTES_HELP_LINK_LABEL"
        data-testid="monthly-usage-overview"
      />
      <usage-overview
        v-if="shouldShowAdditionalMinutes"
        class="gl-pt-5"
        :minutes-title="$options.ADDITIONAL_MINUTES"
        :minutes-used="purchasedMinutesUsed"
        minutes-used-testid-selector="additional-compute-minutes"
        :minutes-used-percentage="usagePercentage(ciMinutesPurchasedMinutesUsedPercentage)"
        :minutes-limit="ciMinutesPurchasedMinutesLimit"
        :help-link-href="$options.ADDITIONAL_MINUTES_HELP_LINK"
        :help-link-label="$options.ADDITIONAL_MINUTES"
        data-testid="purchased-usage-overview"
      />
    </section>

    <div class="gl-display-flex gl-my-5">
      <gl-form-group :label="s__('UsageQuota|Filter charts by year')">
        <gl-collapsible-listbox
          v-model="selectedYear"
          :items="years"
          :disabled="isLoadingYearUsageData"
          data-testid="minutes-usage-year-dropdown"
        />
      </gl-form-group>
    </div>

    <section class="gl-my-5">
      <h2 class="gl-font-lg">{{ $options.USAGE_BY_MONTH_HEADER }}</h2>

      <gl-loading-icon
        v-if="isLoadingYearUsageData"
        class="gl-mt-5"
        size="lg"
        data-testid="pipelines-by-month-chart-loading-indicator"
      />

      <minutes-usage-per-month
        v-else
        :selected-year="selectedYear"
        :ci-minutes-usage="ciMinutesUsage"
      />
    </section>

    <section class="gl-my-5">
      <h2 class="gl-font-lg">{{ $options.USAGE_BY_PROJECT_HEADER }}</h2>

      <div class="gl-display-flex gl-my-3">
        <gl-form-group :label="s__('UsageQuota|Filter projects data by month')">
          <gl-collapsible-listbox
            v-model="selectedMonth"
            :items="months"
            :disabled="isLoadingMonthProjectUsageData"
            data-testid="minutes-usage-month-dropdown"
          />
        </gl-form-group>
      </div>

      <gl-loading-icon
        v-if="isLoadingMonthProjectUsageData"
        class="gl-mt-5"
        size="lg"
        data-testid="pipelines-by-project-chart-loading-indicator"
      />

      <template v-else>
        <gl-alert :dismissible="false" class="gl-my-3" data-testid="project-usage-info-alert">
          <gl-sprintf
            :message="
              s__('UsageQuota|The chart and the table below show usage for %{month} %{year}')
            "
          >
            <template #month>{{ selectedMonthName }}</template>
            <template #year>{{ selectedYear }}</template>
          </gl-sprintf>
        </gl-alert>

        <minutes-usage-per-project
          :selected-year="selectedYear"
          :selected-month="selectedMonth"
          :projects-ci-minutes-usage="projectsCiMinutesUsage"
        />

        <div class="gl-pt-5">
          <project-list
            :projects="projects"
            :page-info="projectsPageInfo"
            @fetchMore="fetchMoreProjects"
          />
        </div>
      </template>
    </section>
  </div>
</template>
