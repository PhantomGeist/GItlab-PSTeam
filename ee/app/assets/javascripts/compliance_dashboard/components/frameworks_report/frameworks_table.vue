<script>
import Vue from 'vue';
import { GlLoadingIcon, GlTable, GlToast, GlLink } from '@gitlab/ui';
import { __, s__ } from '~/locale';

Vue.use(GlToast);

export default {
  name: 'FrameworksTable',
  components: {
    GlLoadingIcon,
    GlTable,
    GlLink,
  },
  props: {
    frameworks: {
      type: Array,
      required: true,
    },
    projects: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    frameworkItems() {
      return this.frameworks.map((framework) => {
        const associatedProjects = this.projects.filter((project) =>
          project.complianceFrameworks.nodes.some((f) => f.id === framework.id),
        );
        return { ...framework, associatedProjects };
      });
    },
  },
  fields: [
    {
      key: 'frameworkName',
      label: __('Frameworks'),
      thClass: 'gl-vertical-align-middle!',
      tdClass: 'gl-vertical-align-middle!',
      sortable: true,
    },
    {
      key: 'associatedProjects',
      label: __('Associated projects'),
      thClass: 'gl-vertical-align-middle!',
      tdClass: 'gl-vertical-align-middle!',
      sortable: false,
    },
  ],
  i18n: {
    noFrameworksFound: s__('ComplianceReport|No frameworks found'),
  },
};
</script>
<template>
  <gl-table
    :fields="$options.fields"
    :busy="isLoading"
    :items="frameworkItems"
    no-local-sorting
    show-empty
    stacked="lg"
    hover
  >
    <template #cell(frameworkName)="{ item }">
      {{ item.name }}
    </template>
    <template #cell(associatedProjects)="{ item: { associatedProjects } }">
      <div v-for="(associatedProject, index) in associatedProjects" :key="associatedProject.id">
        <gl-link :href="associatedProject.webUrl" data-testid="project_name_link">{{
          associatedProject.name
        }}</gl-link
        ><span v-if="index < associatedProjects.length - 1">,</span>
      </div>
    </template>
    <template #table-busy>
      <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
    </template>
    <template #empty>
      <div class="gl-my-5 gl-text-center" data-testid="frameworks-table-empty-state">
        {{ $options.i18n.noFrameworksFound }}
      </div>
    </template>
  </gl-table>
</template>
