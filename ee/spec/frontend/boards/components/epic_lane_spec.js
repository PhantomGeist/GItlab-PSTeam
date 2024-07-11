import { GlButton, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import listsIssuesQuery from '~/boards/graphql/lists_issues.query.graphql';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import EpicLane from 'ee/boards/components/epic_lane.vue';
import IssuesLaneList from 'ee/boards/components/issues_lane_list.vue';
import getters from 'ee/boards/stores/getters';
import updateBoardEpicUserPreferencesMutation from 'ee/boards/graphql/update_board_epic_user_preferences.mutation.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  mockEpic,
  mockLists,
  mockIssuesByListId,
  issues,
  mockGroupIssuesResponse,
} from '../mock_data';

Vue.use(VueApollo);
Vue.use(Vuex);

describe('EpicLane', () => {
  let wrapper;
  let mockApollo;

  const updateBoardEpicUserPreferencesSpy = jest.fn();
  const fetchIssuesForEpicSpy = jest.fn();

  const findChevronButton = () => wrapper.findComponent(GlButton);
  const findIssuesLaneLists = () => wrapper.findAllComponents(IssuesLaneList);
  const findEpicLane = () => wrapper.findByTestId('board-epic-lane');
  const findEpicLaneIssueCount = () => wrapper.findByTestId('epic-lane-issue-count');

  const createStore = ({ boardItemsByListId = mockIssuesByListId, isLoading = false }) => {
    return new Vuex.Store({
      actions: {
        updateBoardEpicUserPreferences: updateBoardEpicUserPreferencesSpy,
        fetchIssuesForEpic: fetchIssuesForEpicSpy,
      },
      state: {
        boardItemsByListId,
        boardItems: issues,
        epicsFlags: {
          [mockEpic.id]: {
            isLoading,
          },
        },
      },
      getters,
    });
  };

  const listIssuesQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupIssuesResponse());
  const errorMessage = 'Failed to fetch issues';
  const listIssuesQueryHandlerFailure = jest.fn().mockRejectedValue(new Error(errorMessage));
  const updateEpicPreferencesMutationHandler = jest.fn();

  const createComponent = ({
    props = {},
    boardItemsByListId = mockIssuesByListId,
    listIssuesQueryHandler = listIssuesQueryHandlerSuccess,
    isLoading = false,
    isApolloBoard = false,
  } = {}) => {
    const store = createStore({ boardItemsByListId, isLoading });
    mockApollo = createMockApollo([
      [listsIssuesQuery, listIssuesQueryHandler],
      [updateBoardEpicUserPreferencesMutation, updateEpicPreferencesMutationHandler],
    ]);

    const defaultProps = {
      epic: mockEpic,
      lists: mockLists,
      boardId: 'gid://gitlab/Board/1',
      filterParams: {},
      totalIssuesCountByListId: {},
    };

    wrapper = shallowMountExtended(EpicLane, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      apolloProvider: mockApollo,
      store,
      provide: {
        fullPath: 'gitlab-org',
        boardType: 'group',
        isApolloBoard,
      },
    });
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  describe('mounted', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls fetchIssuesForEpic action on mount', () => {
      expect(fetchIssuesForEpicSpy).toHaveBeenCalledWith(expect.any(Object), mockEpic.id);
    });
  });

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays count of issues in epic which belong to board', () => {
      expect(findEpicLaneIssueCount().text()).toContain('2');
    });

    it('displays 1 icon', () => {
      expect(wrapper.findAllComponents(GlIcon)).toHaveLength(1);
    });

    it('displays epic title', () => {
      expect(wrapper.text()).toContain(mockEpic.title);
    });

    it('renders one IssuesLaneList component per list passed in props passing lists as props', () => {
      expect(findIssuesLaneLists()).toHaveLength(wrapper.props('lists').length);
      expect(wrapper.findComponent(IssuesLaneList).props('lists')).toEqual(wrapper.props('lists'));
    });

    it('hides issues when collapsing', async () => {
      expect(findIssuesLaneLists()).toHaveLength(wrapper.props('lists').length);
      expect(wrapper.vm.isCollapsed).toBe(false);

      findChevronButton().vm.$emit('click');

      await nextTick();
      expect(findIssuesLaneLists()).toHaveLength(0);
      expect(wrapper.vm.isCollapsed).toBe(true);
    });

    it('does not display loading icon when issues are not loading', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(false);
    });

    it('displays loading icon and hides issues count when issues are loading', () => {
      createComponent({ isLoading: true });
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findEpicLaneIssueCount().exists()).toBe(false);
    });

    it('invokes `updateBoardEpicUserPreferences` method on collapse', async () => {
      const collapsedValue = false;

      expect(wrapper.vm.isCollapsed).toBe(collapsedValue);
      expect(findEpicLane().classes()).toContain('board-epic-lane-shadow');

      findChevronButton().vm.$emit('click');

      await nextTick();
      expect(updateBoardEpicUserPreferencesSpy).toHaveBeenCalled();

      const payload = updateBoardEpicUserPreferencesSpy.mock.calls[0][1];

      expect(payload).toEqual({
        collapsed: !collapsedValue,
        epicId: mockEpic.id,
      });
      expect(wrapper.vm.isCollapsed).toBe(true);
      expect(findEpicLane().classes()).not.toContain('board-epic-lane-shadow');
    });

    it('does not render when issuesCount is 0', () => {
      createComponent({ boardItemsByListId: {} });
      expect(findEpicLane().exists()).toBe(false);
    });
  });

  describe('Apollo boards', () => {
    it('fetches list issues', async () => {
      createComponent({ isApolloBoard: true });

      await nextTick();
      expect(listIssuesQueryHandlerSuccess).toHaveBeenCalled();
    });

    it('sets error when list issues query fails', async () => {
      createComponent({
        listIssuesQueryHandler: listIssuesQueryHandlerFailure,
        isApolloBoard: true,
      });

      await waitForPromises();
      expect(cacheUpdates.setError).toHaveBeenCalled();
    });

    it('updates epic user preferences on collapse', async () => {
      createComponent({
        isApolloBoard: true,
      });

      await waitForPromises();

      const collapsedValue = false;

      expect(findEpicLane().classes()).toContain('board-epic-lane-shadow');
      expect(findIssuesLaneLists()).toHaveLength(wrapper.props('lists').length);

      findChevronButton().vm.$emit('click');

      await waitForPromises();
      expect(updateEpicPreferencesMutationHandler).toHaveBeenCalledWith({
        boardId: 'gid://gitlab/Board/1',
        collapsed: !collapsedValue,
        epicId: mockEpic.id,
      });

      expect(findEpicLane().classes()).not.toContain('board-epic-lane-shadow');
      expect(findIssuesLaneLists()).toHaveLength(0);
    });
  });
});
