import { nextTick } from 'vue';
import { GlDropdownText } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import OperationServiceToken from 'ee/tracing/components/operation_search_token.vue';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

jest.mock('~/alert');

describe('OperationServiceToken', () => {
  let wrapper;

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  const triggerFetchSuggestions = (searchTerm = null) => {
    findBaseToken().vm.$emit('fetch-suggestions', searchTerm);
    return waitForPromises();
  };

  const findSuggestions = () =>
    findBaseToken()
      .props('suggestions')
      .map(({ name }) => ({ name }));
  const isLoadingSuggestions = () => findBaseToken().props('suggestionsLoading');

  let mockFetchOperations = jest.fn();
  const mockOperations = [{ name: 'o1' }, { name: 'o2' }];

  const mountComponent = ({
    active = false,
    loadSuggestionsForServices = [{ name: 's1' }],
  } = {}) => {
    wrapper = shallowMountExtended(OperationServiceToken, {
      propsData: {
        active,
        config: {
          fetchOperations: mockFetchOperations,
          loadSuggestionsForServices,
        },
        value: { data: '' },
      },
    });
  };

  beforeEach(() => {
    mockFetchOperations = jest.fn().mockResolvedValue(mockOperations);
  });

  describe('default', () => {
    beforeEach(() => {
      mountComponent();
    });

    it('renders a BaseToken', () => {
      const base = findBaseToken();
      expect(base.exists()).toBe(true);
      expect(base.props('active')).toBe(wrapper.props('active'));
      expect(base.props('config')).toBe(wrapper.props('config'));
      expect(base.props('value')).toBe(wrapper.props('value'));
    });

    it('does not fetch suggestions if not active', async () => {
      await triggerFetchSuggestions();

      expect(mockFetchOperations).not.toHaveBeenCalled();
    });
  });

  describe('when active', () => {
    beforeEach(() => {
      mountComponent({ active: true });
    });

    it('fetches the operations suggestions', async () => {
      expect(isLoadingSuggestions()).toBe(false);

      await triggerFetchSuggestions();

      expect(mockFetchOperations).toHaveBeenCalled();
      expect(isLoadingSuggestions()).toBe(false);
      expect(wrapper.findComponent(GlDropdownText).exists()).toBe(false);
      expect(findSuggestions()).toEqual(mockOperations);
    });

    it('only fetch suggestions once', async () => {
      await triggerFetchSuggestions();

      await triggerFetchSuggestions();

      expect(mockFetchOperations).toHaveBeenCalledTimes(1);
    });

    it('filters suggestions if a search term is specified', async () => {
      await triggerFetchSuggestions('o1');

      expect(findSuggestions()).toEqual([{ name: 'o1' }]);
    });

    it('sets the loading status', async () => {
      triggerFetchSuggestions();

      await nextTick();

      expect(isLoadingSuggestions()).toBe(true);
    });

    describe('when loadSuggestionsForServices is not empty', () => {
      beforeEach(() => {
        mockFetchOperations.mockImplementation((service) =>
          Promise.resolve({ name: `op-for-${service}` }),
        );
        mountComponent({
          active: true,
          loadSuggestionsForServices: ['s1', 's2'],
        });
      });

      it('fetches the operations suggestions for each service defined in loadSuggestionsForServices', async () => {
        await triggerFetchSuggestions();

        expect(mockFetchOperations).toHaveBeenCalledTimes(2);
        expect(findSuggestions()).toEqual([{ name: 'op-for-s1' }, { name: 'op-for-s2' }]);
      });
    });

    describe('when loadSuggestionsForServices is empty', () => {
      beforeEach(() => {
        mountComponent({
          active: true,
          loadSuggestionsForServices: [],
        });
      });

      it('does not fetch suggestions if loadSuggestionsForServices is empty', async () => {
        await triggerFetchSuggestions();

        expect(mockFetchOperations).not.toHaveBeenCalled();
      });

      it('does shows a dropdown-text if loadSuggestionsForServices is empty', async () => {
        await triggerFetchSuggestions();

        expect(wrapper.findComponent(GlDropdownText).exists()).toBe(true);
        expect(wrapper.findComponent(GlDropdownText).text()).toBe(
          'Select a service to load suggestions',
        );
      });
    });
  });

  describe('when fetching fails', () => {
    beforeEach(() => {
      mockFetchOperations = jest.fn().mockRejectedValue(new Error('error'));
      mountComponent({ active: true });
    });
    it('shows an alert if fetching fails', async () => {
      await triggerFetchSuggestions();
      await nextTick();

      expect(createAlert).toHaveBeenCalled();
      expect(findSuggestions()).toEqual([]);
      expect(isLoadingSuggestions()).toBe(false);
    });
  });
});
