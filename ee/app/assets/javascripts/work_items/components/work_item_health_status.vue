<script>
import { GlFormGroup, GlCollapsibleListbox, GlButton, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import {
  HEALTH_STATUS_I18N_HEALTH_STATUS,
  HEALTH_STATUS_I18N_NO_STATUS,
  HEALTH_STATUS_I18N_NONE,
  healthStatusDropdownOptions,
} from 'ee/sidebar/constants';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  sprintfWorkItem,
  TRACKING_CATEGORY_SHOW,
} from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import Tracking from '~/tracking';

export default {
  HEALTH_STATUS_I18N_HEALTH_STATUS,
  HEALTH_STATUS_I18N_NO_STATUS,
  HEALTH_STATUS_I18N_NONE,
  healthStatusDropdownOptions,
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
    GlButton,
    GlIcon,
    GlLoadingIcon,
    IssueHealthStatus,
  },
  mixins: [Tracking.mixin()],
  inject: ['hasIssuableHealthStatusFeature'],
  props: {
    healthStatus: {
      type: String,
      required: false,
      default: null,
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isFocused: false,
      isLoading: false,
    };
  },
  computed: {
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_health_status',
        property: `type_${this.workItemType}`,
      };
    },
    dropdownToggleClasses() {
      return {
        'is-not-focused': !this.isFocused,
      };
    },
    dropdownItems() {
      const emptyItem = {
        text: this.$options.HEALTH_STATUS_I18N_NO_STATUS,
        value: 'empty',
      };
      return [emptyItem, ...healthStatusDropdownOptions];
    },
    selectedHealthStatus() {
      return this.healthStatus || 'empty';
    },
  },
  methods: {
    isSelected(healthStatus) {
      return this.healthStatus === healthStatus;
    },
    onDropdownShown() {
      this.isFocused = true;
    },
    onDropdownHide() {
      this.isFocused = false;
    },
    updateHealthStatus(healthStatus) {
      if (!this.canUpdate) {
        return;
      }

      this.track('updated_health_status');

      this.isLoading = true;

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              healthStatusWidget: {
                healthStatus: healthStatus === 'empty' ? null : healthStatus,
              },
            },
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          const msg = sprintfWorkItem(I18N_WORK_ITEM_ERROR_UPDATING, this.workItemType);
          this.$emit('error', msg);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isLoading = false;
        });
    },
  },
};
</script>

<template>
  <gl-form-group
    v-if="hasIssuableHealthStatusFeature"
    class="work-item-dropdown"
    :label="$options.HEALTH_STATUS_I18N_HEALTH_STATUS"
    label-class="gl-pb-0! gl-mt-3 gl-overflow-wrap-break gl-display-flex gl-align-items-center work-item-field-label"
    label-cols="3"
    label-cols-lg="2"
  >
    <div v-if="!canUpdate" class="gl-ml-4 gl-mt-3 work-item-field-value">
      <issue-health-status v-if="healthStatus" :health-status="healthStatus" />
      <span v-else class="gl-text-secondary gl-display-inline-block">{{
        $options.HEALTH_STATUS_I18N_NONE
      }}</span>
    </div>
    <gl-collapsible-listbox
      v-else
      :items="dropdownItems"
      :disabled="!canUpdate"
      :loading="isLoading"
      :toggle-class="dropdownToggleClasses"
      :selected="selectedHealthStatus"
      class="gl-mt-3 work-item-field-value"
      data-testid="work-item-health-status-dropdown"
      @shown="onDropdownShown"
      @hidden="onDropdownHide"
      @select="updateHealthStatus"
    >
      <template #toggle>
        <gl-button
          class="gl-dropdown-toggle"
          :class="{ 'is-not-focused': !isFocused }"
          :disabled="isLoading"
        >
          <gl-loading-icon v-if="isLoading" inline />
          <issue-health-status v-if="healthStatus" :health-status="healthStatus" />
          <span v-else class="gl-text-secondary gl-display-inline-block work-item-field-value">{{
            $options.HEALTH_STATUS_I18N_NONE
          }}</span>
          <gl-icon class="dropdown-chevron gl-button-icon gl-ml-2" name="chevron-down" />
        </gl-button>
      </template>
    </gl-collapsible-listbox>
  </gl-form-group>
</template>
