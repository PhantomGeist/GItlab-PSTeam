<script>
import {
  GlIcon,
  GlLink,
  GlSkeletonLoader,
  GlTableLite,
  GlTooltip,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import { projectsUsageDataValidator } from '../utils';

export default {
  name: 'ProductAnalyticsProjectsUsageTable',
  components: {
    GlIcon,
    GlLink,
    GlSkeletonLoader,
    GlTableLite,
    GlTooltip,
    ProjectAvatar,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    isLoading: {
      type: Boolean,
      required: true,
    },
    projectsUsageData: {
      type: Array,
      required: false,
      default: null,
      validator: projectsUsageDataValidator,
    },
  },
  computed: {
    showEmptyState() {
      return this.projectsUsageData?.length === 0;
    },
  },
  TABLE_FIELDS: [
    { key: 'name', label: __('Project') },
    { key: 'currentEvents', label: s__('Analytics|Current month to date') },
    { key: 'previousEvents', label: s__('Analytics|Previous month') },
  ],
};
</script>
<template>
  <div>
    <gl-skeleton-loader v-if="isLoading" :lines="3" :equal-width-lines="true" />
    <div v-else-if="showEmptyState" data-testid="projects-usage-table-empty-state">
      {{
        s__(
          'Analytics|This group has no projects with product analytics onboarded in the current or previous month.',
        )
      }}
    </div>
    <div v-else-if="projectsUsageData" data-testid="projects-usage-table">
      <gl-table-lite :items="projectsUsageData" :fields="$options.TABLE_FIELDS">
        <template #head(currentEvents)="{ field: { label } }">
          {{ label }}
          <gl-icon
            id="events-update-frequency-tooltip"
            v-gl-tooltip
            class="gl-ml-1"
            name="question-o"
            tabindex="0"
            :size="12"
          />
          <gl-tooltip target="events-update-frequency-tooltip">
            {{ s__('Analytics|Event counts update hourly') }}
          </gl-tooltip>
        </template>
        <template #cell(name)="{ item: { id, name, avatarUrl, webUrl } }">
          <project-avatar
            :project-id="id"
            :project-name="name"
            :project-avatar-url="avatarUrl"
            :size="16"
            :alt="name"
            class="gl-mr-2"
          />
          <gl-link
            :href="webUrl"
            class="gl-text-gray-900! gl-word-break-word"
            data-testid="project-link"
          >
            {{ name }}
          </gl-link>
        </template>
      </gl-table-lite>
      <p class="gl-text-center gl-py-5">
        {{
          s__(
            'Analytics|This table excludes projects that do not have product analytics onboarded.',
          )
        }}
      </p>
    </div>
  </div>
</template>
