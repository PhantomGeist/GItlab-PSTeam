<script>
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';

export default {
  name: 'SearchAndSortBar',
  components: {
    FilteredSearchBar,
  },
  inject: ['fullPath'],
  data() {
    return {
      search: undefined,
    };
  },
  methods: {
    onFilter(filterOptions) {
      this.$emit('onFilter', this.getFilterParams(filterOptions));
    },
    getFilterParams(filters = []) {
      const filterParams = {};

      filters.forEach((filter) => {
        if (filter.type === FILTERED_SEARCH_TERM) {
          if (filter.value.data) {
            filterParams.search = filter.value.data;
          }
        }
      });

      return filterParams;
    },
  },
};
</script>

<template>
  <div class="gl-display-flex gl-bg-gray-10 gl-p-3 gl-gap-3">
    <filtered-search-bar
      class="gl-flex-grow-1"
      :namespace="fullPath"
      :tokens="[] /* eslint-disable-line @gitlab/vue-no-new-non-primitive-in-template */"
      :search-input-placeholder="__('Filter users')"
      @onFilter="onFilter"
    />
  </div>
</template>
