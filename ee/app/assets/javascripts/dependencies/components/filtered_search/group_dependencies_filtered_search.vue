<script>
import { GlFilteredSearch } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { __ } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import LicenseToken from './tokens/license_token.vue';

export default {
  components: {
    GlFilteredSearch,
  },
  data() {
    return {
      value: [],
      currentFilterParams: null,
    };
  },
  computed: {
    ...mapState(['currentList']),
    tokens() {
      return [
        {
          type: 'licenses',
          title: __('License'),
          multiSelect: true,
          unique: true,
          token: LicenseToken,
          operators: OPERATORS_IS,
        },
      ];
    },
  },
  methods: {
    ...mapActions({
      fetchFilteredDependencies(dispatch, filters = []) {
        const filterParams = {};

        filters.forEach((filter) => {
          if (Array.isArray(filter.value?.data)) {
            // `value.data` contains the applied filters as a comma seperated string
            filterParams[filter.type] = filter.value.data;
          }
        });

        dispatch(`${this.currentList}/fetchDependencies`, filterParams);
      },
    }),
  },
};
</script>

<template>
  <gl-filtered-search
    v-model="value"
    :placeholder="__('Search or filter dependencies...')"
    :available-tokens="tokens"
    @submit="fetchFilteredDependencies"
  />
</template>
