<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';

import ToggleSidebar from '~/sidebar/components/toggle/toggle_sidebar.vue';

export default {
  components: {
    ToggleSidebar,
  },
  props: {
    sidebarCollapsed: {
      type: Boolean,
      required: true,
    },
  },
  methods: {
    ...mapActions(['toggleSidebar']),
  },
};
</script>

<template>
  <div class="issuable-sidebar-header gl-pb-4!">
    <toggle-sidebar
      :collapsed="sidebarCollapsed"
      css-classes="float-right"
      @toggle="toggleSidebar({ sidebarCollapsed })"
    />
    <slot></slot>
  </div>
</template>
