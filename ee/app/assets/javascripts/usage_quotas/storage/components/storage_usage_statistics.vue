<script>
import { GlSprintf, GlLink, GlButton, GlModalDirective } from '@gitlab/ui';
import { usageQuotasHelpPaths } from '~/usage_quotas/storage/constants';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';
import { BUY_STORAGE, NAMESPACE_STORAGE_OVERVIEW_SUBTITLE } from '../constants';
import LimitedAccessModal from '../../components/limited_access_modal.vue';
import NamespaceLimitsStorageUsageOverviewCard from './namespace_limits_storage_usage_overview_card.vue';
import NamespaceLimitsTotalStorageAvailableBreakdownCard from './namespace_limits_total_storage_available_breakdown_card.vue';
import StorageUsageOverviewCard from './storage_usage_overview_card.vue';
import ProjectLimitsExcessStorageBreakdownCard from './project_limits_excess_storage_breakdown_card.vue';
import NumberToHumanSize from './number_to_human_size.vue';

export default {
  components: {
    GlSprintf,
    GlLink,
    GlButton,
    LimitedAccessModal,
    NamespaceLimitsStorageUsageOverviewCard,
    NamespaceLimitsTotalStorageAvailableBreakdownCard,
    StorageUsageOverviewCard,
    ProjectLimitsExcessStorageBreakdownCard,
    NumberToHumanSize,
  },
  directives: {
    GlModalDirective,
  },
  inject: [
    'purchaseStorageUrl',
    'buyAddonTargetAttr',
    'namespacePlanName',
    'isUsingProjectEnforcement',
    'isUsingNamespaceEnforcement',
    'namespacePlanStorageIncluded',
    'namespaceId',
  ],
  apollo: {
    // handling loading state is not needed in the first iteration of https://gitlab.com/gitlab-org/gitlab/-/issues/409750
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
  props: {
    additionalPurchasedStorageSize: {
      type: Number,
      required: false,
      default: 0,
    },
    usedStorage: {
      type: Number,
      required: false,
      default: 0,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      subscriptionPermissions: {},
      isLimitedAccessModalShown: false,
    };
  },
  usageQuotasHelpPaths,
  i18n: {
    purchaseButtonText: BUY_STORAGE,
    namespaceStorageOverviewSubtitle: NAMESPACE_STORAGE_OVERVIEW_SUBTITLE,
  },
  computed: {
    totalStorage() {
      return this.namespacePlanStorageIncluded + this.additionalPurchasedStorageSize;
    },
    shouldShowLimitedAccessModal() {
      // NOTE: we're using existing flag for seats `canAddSeats`, to infer
      // whether the storage is expandable.
      const canAddStorage = this.subscriptionPermissions?.canAddSeats ?? true;

      return (
        !canAddStorage &&
        gon.features?.limitedAccessModal &&
        LIMITED_ACCESS_KEYS.includes(this.subscriptionPermissions.reason)
      );
    },
  },
  methods: {
    showLimitedAccessModal() {
      this.isLimitedAccessModalShown = true;
    },
  },
};
</script>
<template>
  <div>
    <div class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
      <h3 data-testid="overview-subtitle">{{ $options.i18n.namespaceStorageOverviewSubtitle }}</h3>
      <template v-if="purchaseStorageUrl && !isUsingProjectEnforcement">
        <gl-button
          v-if="!shouldShowLimitedAccessModal"
          :href="purchaseStorageUrl"
          :target="buyAddonTargetAttr"
          category="primary"
          variant="confirm"
          data-testid="purchase-more-storage"
        >
          {{ $options.i18n.purchaseButtonText }}
        </gl-button>

        <gl-button
          v-else
          v-gl-modal-directive="'limited-access-modal-id'"
          category="primary"
          variant="confirm"
          data-testid="purchase-more-storage"
          @click="showLimitedAccessModal"
        >
          {{ $options.i18n.purchaseButtonText }}
        </gl-button>
      </template>
    </div>
    <p class="gl-mb-0">
      <template v-if="namespacePlanStorageIncluded && isUsingNamespaceEnforcement">
        <gl-sprintf :message="s__('UsageQuota|This namespace has %{planLimit} of storage.')">
          <template #planLimit
            ><number-to-human-size :value="namespacePlanStorageIncluded"
          /></template>
        </gl-sprintf>
        <gl-link :href="$options.usageQuotasHelpPaths.usageQuotasNamespaceStorageLimit">{{
          s__('UsageQuota|How are limits applied?')
        }}</gl-link>
      </template>

      <template v-if="namespacePlanStorageIncluded && isUsingProjectEnforcement">
        <gl-sprintf
          :message="s__('UsageQuota|Projects under this namespace have %{planLimit} of storage.')"
        >
          <template #planLimit
            ><number-to-human-size :value="namespacePlanStorageIncluded"
          /></template>
        </gl-sprintf>
        <gl-link :href="$options.usageQuotasHelpPaths.usageQuotasProjectStorageLimit">{{
          s__('UsageQuota|How are limits applied?')
        }}</gl-link>
      </template>
    </p>
    <div class="gl-display-grid gl-md-grid-template-columns-2 gl-gap-5 gl-py-4">
      <namespace-limits-storage-usage-overview-card
        v-if="isUsingNamespaceEnforcement"
        :used-storage="usedStorage"
        :total-storage="totalStorage"
        :loading="loading"
        data-testid="namespace-usage-total"
      />

      <storage-usage-overview-card
        v-else
        :used-storage="usedStorage"
        :loading="loading"
        data-testid="namespace-usage-total"
      />

      <template v-if="namespacePlanName">
        <project-limits-excess-storage-breakdown-card
          v-if="isUsingProjectEnforcement"
          :purchased-storage="additionalPurchasedStorageSize"
          :limited-access-mode-enabled="shouldShowLimitedAccessModal"
          :loading="loading"
        />
        <namespace-limits-total-storage-available-breakdown-card
          v-else
          :included-storage="namespacePlanStorageIncluded"
          :purchased-storage="additionalPurchasedStorageSize"
          :total-storage="totalStorage"
          :loading="loading"
        />
      </template>
    </div>
    <limited-access-modal
      v-if="shouldShowLimitedAccessModal"
      v-model="isLimitedAccessModalShown"
      :limited-access-reason="subscriptionPermissions.reason"
    />
  </div>
</template>
