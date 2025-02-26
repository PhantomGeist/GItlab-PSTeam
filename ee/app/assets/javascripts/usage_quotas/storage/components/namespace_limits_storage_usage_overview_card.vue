<script>
import { GlCard, GlProgressBar, GlSkeletonLoader, GlIcon, GlLink } from '@gitlab/ui';
import { sprintf } from '~/locale';
import { usageQuotasHelpPaths } from '~/usage_quotas/storage/constants';
import {
  STORAGE_STATISTICS_PERCENTAGE_REMAINING,
  STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE,
  STORAGE_STATISTICS_NAMESPACE_STORAGE_USED,
} from '../constants';
import NumberToHumanSize from './number_to_human_size.vue';

export default {
  name: 'NamespaceLimitsStorageUsageOverviewCard',
  components: {
    GlCard,
    GlProgressBar,
    GlSkeletonLoader,
    GlIcon,
    GlLink,
    NumberToHumanSize,
  },
  props: {
    totalStorage: {
      type: Number,
      required: false,
      default: null,
    },
    usedStorage: {
      type: Number,
      required: false,
      default: null,
    },
    loading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    percentageUsed() {
      // don't show the progress bar if there's no total storage
      if (!this.totalStorage || this.usedStorage === null) {
        return null;
      }
      const usedRatio = Math.max(Math.round((this.usedStorage / this.totalStorage) * 100), 0);
      return Math.min(usedRatio, 100);
    },
    percentageRemaining() {
      if (this.percentageUsed === null) {
        return null;
      }

      const percentageRemaining = Math.max(100 - this.percentageUsed, 0);

      return sprintf(STORAGE_STATISTICS_PERCENTAGE_REMAINING, {
        percentageRemaining,
      });
    },
  },
  i18n: {
    STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE,
    STORAGE_STATISTICS_NAMESPACE_STORAGE_USED,
  },
  usageQuotasHelpPaths,
};
</script>

<template>
  <gl-card>
    <gl-skeleton-loader v-if="loading" :height="64">
      <rect width="140" height="30" x="5" y="0" rx="4" />
      <rect width="240" height="10" x="5" y="40" rx="4" />
      <rect width="340" height="10" x="5" y="54" rx="4" />
    </gl-skeleton-loader>

    <div v-else>
      <div class="gl-font-weight-bold" data-testid="namespace-storage-card-title">
        {{ $options.i18n.STORAGE_STATISTICS_NAMESPACE_STORAGE_USED }}

        <gl-link
          :href="$options.usageQuotasHelpPaths.usageQuotasNamespaceStorageLimit"
          target="_blank"
          class="gl-ml-2"
          :aria-label="$options.i18n.STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE"
        >
          <gl-icon name="question-o" />
        </gl-link>
      </div>
      <div class="gl-font-size-h-display gl-font-weight-bold gl-line-height-ratio-1000 gl-my-3">
        <number-to-human-size label-class="gl-font-lg" :value="Number(usedStorage)" plain-zero />
        <template v-if="totalStorage">
          /
          <number-to-human-size label-class="gl-font-lg" :value="Number(totalStorage)" plain-zero />
        </template>
      </div>
      <template v-if="percentageUsed !== null">
        <gl-progress-bar :value="percentageUsed" class="gl-my-4" />
        <div data-testid="namespace-storage-percentage-remaining">
          {{ percentageRemaining }}
        </div>
      </template>
    </div>
  </gl-card>
</template>
