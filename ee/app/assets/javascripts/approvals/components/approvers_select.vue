<script>
import { GlIcon, GlCollapsibleListbox, GlAvatarLabeled } from '@gitlab/ui';
import Api from 'ee/api';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  TYPE_USER,
  TYPE_GROUP,
  DROPDOWN_ITEM_LABEL,
  SEARCH_PLACEHOLDER,
  GROUP_OPTIONS,
  DROPDOWN_OPTION_ALL_GROUPS,
} from '../constants';

function addType(type) {
  return (items) => items.map((obj) => Object.assign(obj, { type }));
}

export default {
  components: {
    GlIcon,
    GlCollapsibleListbox,
    GlAvatarLabeled,
  },
  i18n: {
    toggleText: SEARCH_PLACEHOLDER,
    dropdownItemLabel: DROPDOWN_ITEM_LABEL,
  },
  groupOptions: GROUP_OPTIONS,
  props: {
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
    namespaceId: {
      type: String,
      required: true,
    },
    skipUserIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    skipGroupIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    isInvalid: {
      type: Boolean,
      required: false,
      default: false,
    },
    namespaceType: {
      type: String,
      required: false,
      default: NAMESPACE_TYPES.PROJECT,
    },
  },
  data() {
    return {
      listboxItems: [],
      isSearching: false,
      searchString: '',
      selectedGroupOption: this.$options.groupOptions[0],
    };
  },
  computed: {
    isAllGroupsOptionSelected() {
      return this.selectedGroupOption === DROPDOWN_OPTION_ALL_GROUPS;
    },
  },
  methods: {
    fetchGroupsAndUsers(term) {
      const groupsAsync = this.isAllGroupsOptionSelected
        ? this.fetchGroups(term).then(addType(TYPE_GROUP))
        : this.fetchProjectGroups(term).then(addType(TYPE_GROUP));
      const usersAsync =
        this.namespaceType === NAMESPACE_TYPES.PROJECT
          ? this.fetchProjectUsers(term).then(addType(TYPE_USER))
          : this.fetchGroupUsers(term).then(({ data }) => addType(TYPE_USER)(data));

      return Promise.all([groupsAsync, usersAsync])
        .then(([groups, users]) => groups.concat(users))
        .then((results) => ({ results }));
    },
    fetchGroups(term) {
      // Don't includeAll when search is empty. Otherwise, the user could get a lot of garbage choices.
      // https://gitlab.com/gitlab-org/gitlab/issues/11566
      const includeAll = term.trim().length > 0;

      return Api.groups(term, {
        skip_groups: this.skipGroupIds,
        all_available: includeAll,
        order_by: 'id',
      });
    },
    fetchProjectGroups(term) {
      const hasTerm = term.trim().length > 0;
      const DEVELOPER_ACCESS_LEVEL = 30;

      return Api.projectGroups(this.namespaceId, {
        skip_groups: this.skipGroupIds,
        ...(hasTerm ? { search: term } : {}),
        with_shared: true,
        shared_min_access_level: DEVELOPER_ACCESS_LEVEL,
      });
    },
    fetchProjectUsers(term) {
      return Api.projectUsers(this.namespaceId, term, {
        skip_users: this.skipUserIds,
      });
    },
    fetchGroupUsers(term) {
      return Api.groupMembers(this.namespaceId, {
        query: term,
        skip_users: this.skipUserIds,
      });
    },
    getItems() {
      this.isSearching = true;

      this.fetchGroupsAndUsers(this.searchString)
        .then(({ results }) => {
          this.listboxItems = results.map((result) => ({
            name: result.type === TYPE_USER ? result.name : result.full_name,
            value: `${result.type}.${result.id}`,
            subtitle: result.type === TYPE_USER ? `@${result.username}` : result.full_path,
            ...result,
          }));
        })
        .catch(() => {})
        .finally(() => {
          this.isSearching = false;
        });
    },
    onSearch(term) {
      this.searchString = term;
      this.getItems();
    },
    onSelect(selected) {
      const selectedItem = this.listboxItems.find((item) => {
        return item.value === selected;
      });
      this.$emit('input', [selectedItem]);

      this.listboxItems = this.listboxItems.filter((item) => item.value !== selected);
    },
    selectGroupOption(inputEvent) {
      const option = inputEvent.target.value;

      if (option === this.selectedGroupOption) {
        return;
      }
      this.selectedGroupOption = option;
      this.getItems();
    },
  },
};
</script>

<template>
  <div class="gl-display-flex">
    <gl-collapsible-listbox
      :items="listboxItems"
      :toggle-text="$options.i18n.toggleText"
      :no-caret="true"
      :searchable="true"
      :searching="isSearching"
      :variant="isInvalid ? 'danger' : 'default'"
      category="secondary"
      toggle-class="gl-flex-direction-column gl-align-items-stretch!"
      class="approvers-select"
      @shown.once="getItems"
      @search="onSearch"
      @select="onSelect"
    >
      <template #list-item="{ item }">
        <gl-avatar-labeled
          :label="item.name"
          :sub-label="item.subtitle"
          :src="item.avatar_url"
          :entity-name="item.name"
          :size="32"
        />
      </template>
    </gl-collapsible-listbox>
    <div class="gl-relative gl-ml-4 gl-flex-grow-1">
      <select class="gl-pr-6 form-control select-control" @input="selectGroupOption">
        <option v-for="opt in $options.groupOptions" :key="opt" :value="opt">
          {{ $options.i18n.dropdownItemLabel }} {{ opt }}
        </option>
      </select>
      <gl-icon
        name="chevron-down"
        data-hidden="true"
        class="gl-absolute gl-top-3 gl-right-3 gl-text-gray-500"
      />
    </div>
  </div>
</template>
