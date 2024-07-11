<script>
import ProvisionedObservabilityContainer from '~/observability/components/provisioned_observability_container.vue';
import MetricsList from './list/metrics_list.vue';

export default {
  components: {
    ProvisionedObservabilityContainer,
    MetricsList,
  },
  props: {
    oauthUrl: {
      type: String,
      required: true,
    },
    tracingUrl: {
      type: String,
      required: true,
    },
    servicesUrl: {
      type: String,
      required: true,
    },
    provisioningUrl: {
      type: String,
      required: true,
    },
    operationsUrl: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <provisioned-observability-container
    :oauth-url="oauthUrl"
    :tracing-url="tracingUrl"
    :services-url="servicesUrl"
    :provisioning-url="provisioningUrl"
    :operations-url="operationsUrl"
  >
    <template #default="{ observabilityClient }">
      <metrics-list :observability-client="observabilityClient" />
    </template>
  </provisioned-observability-container>
</template>
