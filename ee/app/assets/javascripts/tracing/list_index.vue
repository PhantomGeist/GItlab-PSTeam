<script>
import ProvisionedObservabilityContainer from '~/observability/components/provisioned_observability_container.vue';
import TracingList from './components/tracing_list.vue';

export default {
  components: {
    ProvisionedObservabilityContainer,
    TracingList,
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
    :provisioning-url="provisioningUrl"
    :services-url="servicesUrl"
    :operations-url="operationsUrl"
  >
    <template #default="{ observabilityClient }">
      <tracing-list :observability-client="observabilityClient" />
    </template>
  </provisioned-observability-container>
</template>
