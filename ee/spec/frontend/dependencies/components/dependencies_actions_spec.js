import { GlSorting, GlSortingItem } from '@gitlab/ui';
import { nextTick } from 'vue';
import DependenciesActions from 'ee/dependencies/components/dependencies_actions.vue';
import GroupDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/group_dependencies_filtered_search.vue';
import createStore from 'ee/dependencies/store';
import { DEPENDENCY_LIST_TYPES } from 'ee/dependencies/store/constants';
import {
  SORT_FIELDS_GROUP,
  SORT_FIELDS_PROJECT,
} from 'ee/dependencies/store/modules/list/constants';
import { TEST_HOST } from 'helpers/test_constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('DependenciesActions component', () => {
  let store;
  let wrapper;
  const { namespace } = DEPENDENCY_LIST_TYPES.all;

  const objectBasicProp = {
    namespaceType: 'project',
    enableProjectSearch: true,
  };

  const factory = ({ propsData, provide } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    wrapper = shallowMountExtended(DependenciesActions, {
      store,
      propsData: { ...propsData },
      stubs: {
        GlSortingItem,
      },
      provide: {
        ...objectBasicProp,
        glFeatures: { groupLevelDependenciesFiltering: true },
        ...provide,
      },
    });
  };

  const findSorting = () => wrapper.findComponent(GlSorting);

  beforeEach(async () => {
    factory({
      propsData: { namespace },
    });
    store.state[namespace].endpoint = `${TEST_HOST}/dependencies.json`;
    await nextTick();
  });

  it('dispatches the right setSortField action on clicking each item in the dropdown', () => {
    const sortingItems = wrapper.findAllComponents(GlSortingItem).wrappers;

    sortingItems.forEach((item) => {
      // trigger() does not work on stubbed/shallow mounted components
      // https://github.com/vuejs/vue-test-utils/issues/919
      item.vm.$emit('click');
    });

    expect(store.dispatch.mock.calls).toEqual(
      expect.arrayContaining(
        Object.keys(SORT_FIELDS_PROJECT).map((field) => [`${namespace}/setSortField`, field]),
      ),
    );
  });

  describe('with namespaceType set to group', () => {
    beforeEach(async () => {
      factory({
        propsData: { namespace },
        provide: { namespaceType: 'group' },
      });
      store.state[namespace].endpoint = `${TEST_HOST}/dependencies.json`;
      await nextTick();
    });

    it('dispatches the right setSortField action on clicking each item in the dropdown', () => {
      const sortingItems = wrapper.findAllComponents(GlSortingItem).wrappers;

      sortingItems.forEach((item) => {
        item.vm.$emit('click');
      });

      expect(store.dispatch.mock.calls).toEqual(
        expect.arrayContaining(
          Object.keys(SORT_FIELDS_GROUP).map((field) => [`${namespace}/setSortField`, field]),
        ),
      );
    });

    describe('with the "enableProjectSearch" set to false', () => {
      beforeEach(async () => {
        factory({
          propsData: { namespace },
          provide: {
            namespaceType: 'group',
            enableProjectSearch: false,
          },
        });
        store.state[namespace].endpoint = `${TEST_HOST}/dependencies.json`;
        await nextTick();
      });

      it('does not dispatch the "license" action', () => {
        const sortingItems = wrapper.findAllComponents(GlSortingItem).wrappers;

        sortingItems.forEach((item) => {
          item.vm.$emit('click');
        });

        expect(store.dispatch.mock.calls).not.toEqual(
          expect.arrayContaining([[`${namespace}/setSortField`, 'license']]),
        );
      });
    });

    describe('with the "groupLevelDependenciesFiltering" feature flag disabled', () => {
      beforeEach(async () => {
        factory({
          propsData: { namespace },
          provide: {
            namespaceType: 'group',
            glFeatures: { groupLevelDependenciesFiltering: false },
          },
        });
        await nextTick();
      });

      it('does not render a filtered-search input', () => {
        expect(wrapper.findComponent(GroupDependenciesFilteredSearch).exists()).toBe(false);
      });
    });
  });

  it('dispatches the toggleSortOrder action on clicking the sort order button', () => {
    findSorting().vm.$emit('sortDirectionChange');
    expect(store.dispatch).toHaveBeenCalledWith(`${namespace}/toggleSortOrder`);
  });
});
