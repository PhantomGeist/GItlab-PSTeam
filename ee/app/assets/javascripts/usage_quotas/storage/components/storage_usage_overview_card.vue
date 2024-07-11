<script>
import { GlCard, GlSkeletonLoader } from '@gitlab/ui';
import {
  STORAGE_STATISTICS_NAMESPACE_STORAGE_USED,
  PROJECT_ENFORCEMENT_TYPE_CARD_SUBTITLE,
} from '../constants';
import NumberToHumanSize from './number_to_human_size.vue';

export default {
  name: 'StorageUsageOverviewCard',
  components: {
    GlCard,
    GlSkeletonLoader,
    NumberToHumanSize,
  },
  props: {
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
  i18n: {
    STORAGE_STATISTICS_NAMESPACE_STORAGE_USED,
    PROJECT_ENFORCEMENT_TYPE_CARD_SUBTITLE,
  },
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
      </div>
      <div class="gl-font-size-h-display gl-font-weight-bold gl-line-height-ratio-1000 gl-my-3">
        <number-to-human-size label-class="gl-font-lg" :value="Number(usedStorage)" plain-zero />
      </div>
      <hr class="gl-my-4" />
      <p>{{ $options.i18n.PROJECT_ENFORCEMENT_TYPE_CARD_SUBTITLE }}</p>
    </div>
  </gl-card>
</template>
