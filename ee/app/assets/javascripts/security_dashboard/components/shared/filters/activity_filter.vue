<script>
import { GlBadge, GlCollapsibleListbox } from '@gitlab/ui';
import { without } from 'lodash';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import QuerystringSync from './querystring_sync.vue';
import { ALL_ID } from './constants';

export const ITEMS = {
  STILL_DETECTED: {
    value: 'STILL_DETECTED',
    text: s__('SecurityReports|Still detected'),
  },
  NO_LONGER_DETECTED: {
    value: 'NO_LONGER_DETECTED',
    text: s__('SecurityReports|No longer detected'),
  },
  HAS_ISSUE: {
    value: 'HAS_ISSUE',
    text: s__('SecurityReports|Has issue'),
  },
  DOES_NOT_HAVE_ISSUE: {
    value: 'DOES_NOT_HAVE_ISSUE',
    text: s__('SecurityReports|Does not have issue'),
  },
  HAS_MERGE_REQUEST: {
    value: 'HAS_MERGE_REQUEST',
    text: s__('SecurityReports|Has merge request'),
  },
  DOES_NOT_HAVE_MERGE_REQUEST: {
    value: 'DOES_NOT_HAVE_MERGE_REQUEST',
    text: s__('SecurityReports|Does not have merge request'),
  },
};

export const GROUPS_MR = {
  text: s__('SecurityReports|Merge Request'),
  options: [ITEMS.HAS_MERGE_REQUEST, ITEMS.DOES_NOT_HAVE_MERGE_REQUEST],
  icon: 'git-merge',
};

export const GROUPS = [
  {
    text: '',
    options: [
      {
        value: ALL_ID,
        text: s__('SecurityReports|All activity'),
      },
    ],
    textSrOnly: true,
  },
  {
    text: s__('SecurityReports|Detection'),
    options: [ITEMS.STILL_DETECTED, ITEMS.NO_LONGER_DETECTED],
    icon: 'check-circle-dashed',
    variant: 'info',
  },
  {
    text: s__('SecurityReports|Issue'),
    options: [ITEMS.HAS_ISSUE, ITEMS.DOES_NOT_HAVE_ISSUE],
    icon: 'issues',
  },
];

export default {
  components: {
    GlBadge,
    QuerystringSync,
    GlCollapsibleListbox,
  },
  mixins: [glFeatureFlagsMixin()],
  data: () => ({
    selected: [],
  }),
  computed: {
    toggleText() {
      return getSelectedOptionsText({
        options: Object.values(ITEMS),
        selected: this.selected,
        placeholder: this.$options.i18n.allItemsText,
      });
    },
    selectedItems() {
      return this.selected.length ? this.selected : [ALL_ID];
    },
    items() {
      const groups = [...GROUPS];
      if (this.glFeatures.activityFilterHasMr) {
        groups.push(GROUPS_MR);
      }
      return groups;
    },
  },
  watch: {
    selected() {
      let hasResolution;
      let hasIssues;
      let hasMergeRequest;
      // The above variables can be true, false, or unset, so we need to use if/else-if here instead
      // of if/else.
      if (this.selected.includes(ITEMS.NO_LONGER_DETECTED.value)) {
        hasResolution = true;
      } else if (this.selected.includes(ITEMS.STILL_DETECTED.value)) {
        hasResolution = false;
      }

      if (this.selected.includes(ITEMS.HAS_ISSUE.value)) {
        hasIssues = true;
      } else if (this.selected.includes(ITEMS.DOES_NOT_HAVE_ISSUE.value)) {
        hasIssues = false;
      }

      if (this.glFeatures.activityFilterHasMr) {
        if (this.selected.includes(ITEMS.HAS_MERGE_REQUEST.value)) {
          hasMergeRequest = true;
        } else if (this.selected.includes(ITEMS.DOES_NOT_HAVE_MERGE_REQUEST.value)) {
          hasMergeRequest = false;
        }
      }

      this.$emit('filter-changed', {
        hasResolution,
        hasIssues,
        ...(this.glFeatures.activityFilterHasMr ? { hasMergeRequest } : {}),
      });
    },
  },
  methods: {
    getGroupFromItem(value) {
      return this.items.find((group) =>
        group.options.map((option) => option.value).includes(value),
      );
    },
    updateSelected(selected) {
      const selectedValue = selected?.at(-1);

      // If the ALL_ID option is being selected (last item in selected) or
      // it's clicked when already selected, the selected items should be empty
      if (selectedValue === ALL_ID) {
        this.selected = [];
        return;
      }

      const selectedWithoutAll = without(selected, ALL_ID);
      // Test whether a new item is selected by checking if `selected`
      // (without ALL_ID option) length is larger than `this.selected` length.
      const isSelecting = selectedWithoutAll.length > this.selected.length;
      // If a new item is selected, clear other selected items from the same group and select the new item.
      if (isSelecting) {
        const group = this.getGroupFromItem(selectedValue);
        const groupItemIds = group.options.map((option) => option.value);
        this.selected = without(this.selected, ...groupItemIds).concat(selectedValue);
      }
      // Otherwise, if item is being unselected, just take `selectedWithoutAll` as `this.selected`.
      else {
        this.selected = selectedWithoutAll;
      }
    },
  },
  i18n: {
    label: s__('SecurityReports|Activity'),
    allItemsText: s__('SecurityReports|All activity'),
  },
};
</script>

<template>
  <div>
    <querystring-sync v-model="selected" querystring-key="activity" />
    <label class="gl-mb-2">{{ $options.i18n.label }}</label>
    <gl-collapsible-listbox
      :items="items"
      :selected="selectedItems"
      :header-text="$options.i18n.label"
      :toggle-text="toggleText"
      multiple
      block
      data-testid="filter-activity-dropdown"
      @select="updateSelected"
    >
      <template #group-label="{ group }">
        <div
          v-if="group.icon"
          class="gl--flex-center gl-pr-4"
          :data-testid="`header-${group.text}`"
        >
          <div class="gl-flex-grow-1">{{ group.text }}</div>
          <gl-badge :icon="group.icon" :variant="group.variant" />
        </div>
      </template>
    </gl-collapsible-listbox>
  </div>
</template>
