import { GlCollapsibleListbox, GlSearchBoxByType, GlModal, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableFilterBar from 'ee/geo_replicable/components/geo_replicable_filter_bar.vue';
import { FILTER_OPTIONS, FILTER_STATES, ACTION_TYPES } from 'ee/geo_replicable/constants';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { MOCK_REPLICABLE_TYPE, MOCK_BASIC_GRAPHQL_DATA } from '../mock_data';

Vue.use(Vuex);

describe('GeoReplicableFilterBar', () => {
  let wrapper;

  const actionSpies = {
    setSearch: jest.fn(),
    setStatusFilter: jest.fn(),
    fetchReplicableItems: jest.fn(),
    initiateAllReplicableAction: jest.fn(),
  };

  const defaultState = {
    replicableItems: MOCK_BASIC_GRAPHQL_DATA,
    verificationEnabled: true,
  };

  const createComponent = (initialState = {}, featureFlags = {}) => {
    const store = new Vuex.Store({
      state: { ...defaultState, ...initialState },
      actions: actionSpies,
      getters: {
        replicableTypeName: () => MOCK_REPLICABLE_TYPE,
      },
    });

    wrapper = shallowMountExtended(GeoReplicableFilterBar, {
      store,
      directives: {
        GlModalDirective: createMockDirective('gl-modal-directive'),
      },
      provide: { glFeatures: { ...featureFlags } },
      stubs: { GlModal, GlSprintf },
    });
  };

  const findNavContainer = () => wrapper.find('nav');
  const findGlCollapsibleListbox = () => findNavContainer().findComponent(GlCollapsibleListbox);
  const findGlSearchBox = () => findNavContainer().findComponent(GlSearchBoxByType);
  const findResyncAllButton = () => wrapper.findByTestId('geo-resync-all');
  const findReverifyAllButton = () => wrapper.findByTestId('geo-reverify-all');
  const findGlModal = () => findNavContainer().findComponent(GlModal);

  const getFilterItems = (filters) => {
    return filters.map((filter) => {
      if (filter.value === FILTER_STATES.ALL.value) {
        return { ...filter, text: `${filter.label} ${MOCK_REPLICABLE_TYPE}` };
      }

      return { ...filter, text: filter.label };
    });
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the nav container', () => {
      expect(findNavContainer().exists()).toBe(true);
    });

    it('renders the GlCollapsibleListbox', () => {
      expect(findGlCollapsibleListbox().exists()).toBe(true);
    });

    it('properly formats the dropdownItems', () => {
      expect(findGlCollapsibleListbox().props('items')).toStrictEqual(
        getFilterItems(FILTER_OPTIONS),
      );
    });

    it('does not render search box', () => {
      expect(findGlSearchBox().exists()).toBe(false);
    });

    describe.each`
      replicableItems            | verificationEnabled | showResyncAll | showReverifyAll
      ${[]}                      | ${false}            | ${false}      | ${false}
      ${MOCK_BASIC_GRAPHQL_DATA} | ${false}            | ${true}       | ${false}
      ${[]}                      | ${true}             | ${false}      | ${false}
      ${MOCK_BASIC_GRAPHQL_DATA} | ${true}             | ${true}       | ${true}
    `(
      'Bulk Actions',
      ({ replicableItems, verificationEnabled, showResyncAll, showReverifyAll }) => {
        beforeEach(() => {
          createComponent({ replicableItems, verificationEnabled });
        });

        it(`does ${showResyncAll ? '' : 'not '}render Resync All Button`, () => {
          expect(findResyncAllButton().exists()).toBe(showResyncAll);
        });

        it(`does ${showReverifyAll ? '' : 'not '}render Reverify All Button`, () => {
          expect(findReverifyAllButton().exists()).toBe(showReverifyAll);
        });
      },
    );
  });

  describe('Filter Selected', () => {
    beforeEach(() => {
      createComponent();
    });

    it('clicking a filter item calls setStatusFilter with value and fetchReplicableItems', () => {
      const index = 1;
      findGlCollapsibleListbox().vm.$emit('select', FILTER_OPTIONS[index].value);

      expect(actionSpies.setStatusFilter).toHaveBeenCalledWith(
        expect.any(Object),
        FILTER_OPTIONS[index].value,
      );
      expect(actionSpies.fetchReplicableItems).toHaveBeenCalled();
    });
  });

  // To be implemented via https://gitlab.com/gitlab-org/gitlab/-/issues/411982
  describe('Search box actions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render GlSearchBox', () => {
      expect(findGlSearchBox().exists()).toBe(false);
    });
  });

  describe('Bulk actions modal', () => {
    describe('Resync All', () => {
      beforeEach(() => {
        createComponent({});
        findResyncAllButton().vm.$emit('click');
      });

      it('properly populates the modal data', () => {
        expect(findGlModal().props('title')).toBe(`Resync all ${MOCK_REPLICABLE_TYPE}`);
        expect(findGlModal().text()).toContain(`This will resync all ${MOCK_REPLICABLE_TYPE}.`);
      });

      it('dispatches initiateAllReplicableAction when confirmed', () => {
        findGlModal().vm.$emit('primary');

        expect(actionSpies.initiateAllReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
          action: ACTION_TYPES.RESYNC_ALL,
        });
      });
    });

    describe('Reverify All', () => {
      beforeEach(() => {
        createComponent({});
        findReverifyAllButton().vm.$emit('click');
      });

      it('properly populates the modal data', () => {
        expect(findGlModal().props('title')).toBe(`Reverify all ${MOCK_REPLICABLE_TYPE}`);
        expect(findGlModal().text()).toContain(`This will reverify all ${MOCK_REPLICABLE_TYPE}.`);
      });

      it('dispatches initiateAllReplicableAction when confirmed', () => {
        findGlModal().vm.$emit('primary');

        expect(actionSpies.initiateAllReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
          action: ACTION_TYPES.REVERIFY_ALL,
        });
      });
    });
  });
});
