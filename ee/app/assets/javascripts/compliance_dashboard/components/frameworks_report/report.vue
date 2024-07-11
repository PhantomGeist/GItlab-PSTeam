<script>
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import { s__ } from '~/locale';

import complianceFrameworks from '../../../graphql_shared/queries/get_compliance_framework.query.graphql';
import complianceFrameworksProjects from '../../../graphql_shared/queries/get_compliance_framework_associated_projects.query.graphql';
import FrameworksTable from './frameworks_table.vue';

export default {
  name: 'ComplianceProjectsReport',
  components: {
    GlAlert,
    FrameworksTable,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      hasQueryError: false,
      frameworks: [],
      projects: [],
    };
  },
  apollo: {
    frameworks: {
      query: complianceFrameworks,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      update(data) {
        return data.namespace.complianceFrameworks.nodes;
      },
      error(e) {
        Sentry.captureException(e);
        this.hasQueryError = true;
      },
    },
    projects: {
      query: complianceFrameworksProjects,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      update(data) {
        return data.group.projects.nodes;
      },
      error(e) {
        Sentry.captureException(e);
        this.hasQueryError = true;
      },
    },
  },
  computed: {
    isLoading() {
      return Boolean(this.$apollo.queries.frameworks.loading);
    },
  },
  i18n: {
    queryError: s__(
      'ComplianceReport|Unable to load the compliance framework report. Refresh the page and try again.',
    ),
  },
};
</script>

<template>
  <section>
    <gl-alert v-if="hasQueryError" variant="danger" class="gl-my-3" :dismissible="false">
      {{ $options.i18n.queryError }}
    </gl-alert>

    <frameworks-table
      v-else
      :is-loading="isLoading"
      :frameworks="frameworks"
      :projects="projects"
    />
  </section>
</template>
