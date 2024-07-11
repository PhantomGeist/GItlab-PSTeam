import { shallowMount } from '@vue/test-utils';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';

describe('SearchAndSortBar', () => {
  let wrapper;

  const fullPath = 'namespace/full-path';
  const defaultProps = {
    namespace: fullPath,
    searchInputPlaceholder: 'Filter users',
  };

  const createComponent = () => {
    wrapper = shallowMount(SearchAndSortBar, {
      provide: {
        fullPath,
      },
    });
  };

  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);

  describe('renders filtered search and sort bar', () => {
    it('renders search and sort bar with default params', () => {
      createComponent();

      expect(findFilteredSearchBar().props()).toMatchObject(defaultProps);
    });
  });

  describe('search', () => {
    it('emits search event with appropriate params', () => {
      const searchTerm = 'search term';
      const searchTokens = [
        { type: 'filtered-search-term', value: { data: searchTerm } },
        { type: 'filtered-search-term', value: { data: '' } },
      ];

      createComponent();
      findFilteredSearchBar().vm.$emit('onFilter', searchTokens);

      expect(wrapper.emitted('onFilter')[0][0]).toEqual({ search: searchTerm });
    });

    it('emits search event with empty object on invalid params', () => {
      const searchTokens = [{ type: 'status', value: { data: 'test' } }];

      createComponent();
      findFilteredSearchBar().vm.$emit('onFilter', searchTokens);

      expect(wrapper.emitted('onFilter')[0][0]).toEqual({});
    });
  });
});
