<script>
import { GlLabel, GlLink, GlIcon, GlTooltipDirective, GlButton } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { isScopedLabel } from '~/lib/utils/common_utils';
import RichTimestampTooltip from '~/vue_shared/components/rich_timestamp_tooltip.vue';
import WorkItemLinkChildMetadata from 'ee_else_ce/work_items/components/shared/work_item_link_child_metadata.vue';
import {
  STATE_OPEN,
  TASK_TYPE_NAME,
  WIDGET_TYPE_PROGRESS,
  WIDGET_TYPE_HIERARCHY,
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_MILESTONE,
  WIDGET_TYPE_ASSIGNEES,
  WIDGET_TYPE_LABELS,
  WORK_ITEM_NAME_TO_ICON_MAP,
} from '../../constants';

export default {
  i18n: {
    confidential: __('Confidential'),
    created: __('Created'),
    closed: __('Closed'),
    remove: s__('WorkItem|Remove'),
  },
  components: {
    GlLabel,
    GlLink,
    GlIcon,
    GlButton,
    RichTimestampTooltip,
    WorkItemLinkChildMetadata,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    childItem: {
      type: Object,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: true,
    },
    /*
      This flag is added to manage between two different work items; Task and Objective/Key result.
      Status icon is shown on the task while the actual task icon is shown on any Objective/Key result.
    */
    showTaskIcon: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isFocused: false,
    };
  },
  computed: {
    labels() {
      return this.metadataWidgets[WIDGET_TYPE_LABELS]?.labels?.nodes || [];
    },
    metadataWidgets() {
      return this.childItem.widgets?.reduce((metadataWidgets, widget) => {
        // Skip Hierarchy widget as it is not part of metadata.
        if (widget.type && widget.type !== WIDGET_TYPE_HIERARCHY) {
          // eslint-disable-next-line no-param-reassign
          metadataWidgets[widget.type] = widget;
        }
        return metadataWidgets;
      }, {});
    },
    allowsScopedLabels() {
      return this.metadataWidgets[WIDGET_TYPE_LABELS]?.allowsScopedLabels;
    },
    isChildItemOpen() {
      return this.childItem.state === STATE_OPEN;
    },
    iconName() {
      if (this.childItemType === TASK_TYPE_NAME && !this.showTaskIcon) {
        return this.isChildItemOpen ? 'issue-open-m' : 'issue-close';
      }
      return WORK_ITEM_NAME_TO_ICON_MAP[this.childItemType];
    },
    childItemType() {
      return this.childItem.workItemType.name;
    },
    iconClass() {
      if (this.childItemType === TASK_TYPE_NAME && !this.showTaskIcon) {
        return this.isChildItemOpen ? 'gl-text-green-500' : 'gl-text-blue-500';
      }
      return '';
    },
    stateTimestamp() {
      return this.isChildItemOpen ? this.childItem.createdAt : this.childItem.closedAt;
    },
    stateTimestampTypeText() {
      return this.isChildItemOpen ? this.$options.i18n.created : this.$options.i18n.closed;
    },
    hasMetadata() {
      if (this.metadataWidgets) {
        return (
          Number.isInteger(this.metadataWidgets[WIDGET_TYPE_PROGRESS]?.progress) ||
          Boolean(this.metadataWidgets[WIDGET_TYPE_HEALTH_STATUS]?.healthStatus) ||
          Boolean(this.metadataWidgets[WIDGET_TYPE_MILESTONE]?.milestone) ||
          this.metadataWidgets[WIDGET_TYPE_ASSIGNEES]?.assignees?.nodes.length > 0 ||
          this.metadataWidgets[WIDGET_TYPE_LABELS]?.labels?.nodes.length > 0
        );
      }
      return false;
    },
    showRemove() {
      return this.canUpdate && this.isFocused;
    },
  },
  methods: {
    showScopedLabel(label) {
      return isScopedLabel(label) && this.allowsScopedLabels;
    },
  },
};
</script>

<template>
  <div
    class="item-body work-item-link-child gl-relative gl-display-flex gl-flex-grow-1 gl-overflow-break-word gl-min-w-0 gl-pl-3 gl-pr-2 gl-py-2 gl-mx-n2 gl-rounded-base gl-gap-3"
    data-testid="links-child"
    @mouseover="isFocused = true"
    @mouseleave="isFocused = false"
    @focusin="isFocused = true"
    @focusout="isFocused = false"
  >
    <div class="item-contents gl-display-flex gl-flex-grow-1 gl-flex-wrap gl-min-w-0">
      <div
        class="gl-display-flex gl-flex-grow-1 gl-flex-wrap flex-xl-nowrap gl-align-items-center gl-justify-content-space-between gl-gap-3 gl-min-w-0"
      >
        <div class="item-title gl-display-flex gl-gap-3 gl-min-w-0">
          <span
            :id="`stateIcon-${childItem.id}`"
            class="gl-cursor-help"
            data-testid="item-status-icon"
          >
            <gl-icon
              class="gl-text-secondary"
              :class="iconClass"
              :name="iconName"
              :aria-label="stateTimestampTypeText"
            />
          </span>
          <rich-timestamp-tooltip
            :target="`stateIcon-${childItem.id}`"
            :raw-timestamp="stateTimestamp"
            :timestamp-type-text="stateTimestampTypeText"
          />
          <span v-if="childItem.confidential">
            <gl-icon
              v-gl-tooltip.top
              name="eye-slash"
              class="gl-text-orange-500"
              data-testid="confidential-icon"
              :aria-label="$options.i18n.confidential"
              :title="$options.i18n.confidential"
            />
          </span>
          <gl-link
            :href="childItem.webUrl"
            class="gl-overflow-break-word gl-font-weight-semibold"
            @click="$emit('click', $event)"
            @mouseover="$emit('mouseover')"
            @mouseout="$emit('mouseout')"
          >
            {{ childItem.title }}
          </gl-link>
        </div>
        <work-item-link-child-metadata
          v-if="hasMetadata"
          :metadata-widgets="metadataWidgets"
          class="gl-ml-6 ml-xl-0"
        />
      </div>
      <div v-if="labels.length" class="gl-display-flex gl-flex-wrap gl-flex-basis-full gl-ml-6">
        <gl-label
          v-for="label in labels"
          :key="label.id"
          :title="label.title"
          :background-color="label.color"
          :description="label.description"
          :scoped="showScopedLabel(label)"
          class="gl-my-2 gl-mr-2 gl-mb-auto gl-label-sm"
          tooltip-placement="top"
        />
      </div>
    </div>
    <div v-if="canUpdate">
      <gl-button
        :class="{ 'gl-visibility-visible': showRemove }"
        class="gl-visibility-hidden"
        category="tertiary"
        size="small"
        icon="close"
        :aria-label="$options.i18n.remove"
        data-testid="remove-work-item-link"
        @click="$emit('removeChild', childItem)"
      />
    </div>
  </div>
</template>
