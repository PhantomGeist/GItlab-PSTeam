<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import MetricsTable from './metrics_table.vue';

export default {
  components: {
    GlLoadingIcon,
    MetricsTable,
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
      metrics: [],
    };
  },
  created() {
    this.fetchMetrics();
  },
  methods: {
    async fetchMetrics() {
      this.loading = true;
      try {
        const { metrics } = await this.observabilityClient.fetchMetrics();
        this.metrics = metrics;
      } catch {
        createAlert({
          message: s__('Metrics|Failed to load metrics.'),
        });
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <div v-if="loading" class="gl-py-5">
      <gl-loading-icon size="lg" />
    </div>

    <div v-else class="gl-my-8">
      <metrics-table :metrics="metrics" @reload="fetchMetrics" />
    </div>
  </div>
</template>
