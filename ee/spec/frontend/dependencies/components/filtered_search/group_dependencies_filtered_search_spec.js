import { shallowMount } from '@vue/test-utils';
import { GlFilteredSearch } from '@gitlab/ui';
import GroupDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/group_dependencies_filtered_search.vue';
import LicenseToken from 'ee/dependencies/components/filtered_search/tokens/license_token.vue';
import createStore from 'ee/dependencies/store';

describe('GroupDependenciesFilteredSearch', () => {
  let wrapper;
  let store;

  const createVuexStore = () => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createComponent = () => {
    wrapper = shallowMount(GroupDependenciesFilteredSearch, { store });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  beforeEach(() => {
    createVuexStore();
    createComponent();
  });

  describe('search input', () => {
    it('displays the correct placeholder', () => {
      expect(findFilteredSearch().props('placeholder')).toBe('Search or filter dependencies...');
    });

    it.each`
      tokenTitle   | tokenConfig
      ${'License'} | ${{ title: 'License', type: 'licenses', multiSelect: true, token: LicenseToken }}
    `('contains a "$tokenTitle" search token', ({ tokenConfig }) => {
      expect(findFilteredSearch().props('availableTokens')).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            ...tokenConfig,
          }),
        ]),
      );
    });
  });

  describe('submit', () => {
    it.each`
      filterData               | expectedPayload
      ${['MIT']}               | ${['MIT']}
      ${['MIT', 'Apache 2.0']} | ${['MIT', 'Apache 2.0']}
    `(
      'dispatches the "fetchDependencies" Vuex action with the correct payload when the filter-data is "$filterData',
      ({ filterData, expectedPayload }) => {
        expect(store.dispatch).not.toHaveBeenCalled();

        findFilteredSearch().vm.$emit('submit', [{ type: 'license', value: { data: filterData } }]);

        expect(store.dispatch).toHaveBeenCalledWith('allDependencies/fetchDependencies', {
          license: expectedPayload,
        });
      },
    );
  });
});
