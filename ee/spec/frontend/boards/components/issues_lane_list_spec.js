import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import Draggable from 'vuedraggable';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DraggableItemTypes } from 'ee_else_ce/boards/constants';
import listQuery from 'ee_else_ce/boards/graphql/board_lists_deferred.query.graphql';
import IssuesLaneList from 'ee/boards/components/issues_lane_list.vue';
import eventHub from '~/boards/eventhub';
import BoardCard from '~/boards/components/board_card.vue';
import BoardNewIssue from '~/boards/components/board_new_issue.vue';
import { ListType } from '~/boards/constants';
import listsIssuesQuery from '~/boards/graphql/lists_issues.query.graphql';
import issueCreateMutation from '~/boards/graphql/issue_create.mutation.graphql';
import { createStore } from '~/boards/stores';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import issueMoveListMutation from 'ee/boards/graphql/issue_move_list.mutation.graphql';
import { mockList, boardListQueryResponse } from 'jest/boards/mock_data';
import {
  mockIssues,
  mockGroupIssuesResponse,
  mockLists,
  moveIssueMutationResponse,
  createIssueMutationResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('IssuesLaneList', () => {
  let wrapper;
  let store;
  let mockApollo;

  const findNewIssueForm = () => wrapper.findComponent(BoardNewIssue);

  const listIssuesQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupIssuesResponse());
  const moveIssueMutationHandlerSuccess = jest.fn().mockResolvedValue(moveIssueMutationResponse);
  const createIssueMutationHandlerSuccess = jest
    .fn()
    .mockResolvedValue(createIssueMutationResponse);
  const queryHandlerFailure = jest.fn().mockRejectedValue(new Error('error'));

  const createComponent = ({
    listType = ListType.backlog,
    listProps = {},
    collapsed = false,
    isUnassignedIssuesLane = false,
    canAdminEpic = false,
    totalIssuesCount = 2,
    isApolloBoard = false,
    listsIssuesQueryHandler = listIssuesQueryHandlerSuccess,
    moveIssueMutationHandler = moveIssueMutationHandlerSuccess,
    createIssueMutationHandler = createIssueMutationHandlerSuccess,
  } = {}) => {
    const listMock = {
      ...mockList,
      ...listProps,
      listType,
      collapsed,
    };

    if (listType === ListType.assignee) {
      delete listMock.label;
      listMock.user = {};
    }

    mockApollo = createMockApollo([
      [listsIssuesQuery, listsIssuesQueryHandler],
      [issueMoveListMutation, moveIssueMutationHandler],
      [issueCreateMutation, createIssueMutationHandler],
    ]);
    const baseVariables = {
      fullPath: 'gitlab-org',
      boardId: 'gid://gitlab/Board/1',
      isGroup: true,
      isProject: false,
      first: 10,
    };
    mockApollo.clients.defaultClient.writeQuery({
      query: listsIssuesQuery,
      variables: {
        ...baseVariables,
        filters: { epicId: null },
      },
      data: mockGroupIssuesResponse().data,
    });
    mockApollo.clients.defaultClient.writeQuery({
      query: listsIssuesQuery,
      variables: {
        ...baseVariables,
        filters: { epicWildcardId: 'NONE' },
        id: 'gid://gitlab/List/2',
      },
      data: mockGroupIssuesResponse('gid://gitlab/List/2').data,
    });
    mockApollo.clients.defaultClient.writeQuery({
      query: listQuery,
      variables: { id: 'gid://gitlab/List/1', filters: {} },
      data: boardListQueryResponse({ listId: 'gid://gitlab/List/1' }).data,
    });
    mockApollo.clients.defaultClient.writeQuery({
      query: listQuery,
      variables: { id: 'gid://gitlab/List/2', filters: {} },
      data: boardListQueryResponse({ listId: 'gid://gitlab/List/2' }).data,
    });

    wrapper = shallowMount(IssuesLaneList, {
      apolloProvider: mockApollo,
      store,
      propsData: {
        boardId: 'gid://gitlab/Board/1',
        list: listMock,
        issues: mockIssues,
        canAdminList: true,
        canAdminEpic,
        isUnassignedIssuesLane,
        filterParams: {},
        lists: mockLists,
        totalIssuesCount,
      },
      provide: {
        fullPath: 'gitlab-org',
        boardType: 'group',
        isApolloBoard,
      },
    });
  };

  const findDraggable = () => wrapper.findComponent(Draggable);
  const findList = () => wrapper.find('ul');

  const endDrag = (params) => {
    findDraggable().vm.$emit('end', params);
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  describe('if list is expanded', () => {
    beforeEach(() => {
      store = createStore();

      createComponent();
    });

    it('does not have is-collapsed class', () => {
      expect(wrapper.classes('is-collapsed')).toBe(false);
    });

    it('renders one BoardCard component per issue passed in props', () => {
      expect(wrapper.findAllComponents(BoardCard)).toHaveLength(wrapper.props('issues').length);
    });
  });

  describe('if list is collapsed', () => {
    beforeEach(() => {
      store = createStore();

      createComponent({ collapsed: true });
    });

    it('has is-collapsed class', () => {
      expect(wrapper.classes('is-collapsed')).toBe(true);
    });

    it('does not renders BoardCard components', () => {
      expect(wrapper.findAllComponents(BoardCard)).toHaveLength(0);
    });
  });

  describe('drag & drop permissions', () => {
    beforeEach(() => {
      store = createStore();

      createComponent();
    });

    it('user cannot drag on epic lane if canAdminEpic is false', () => {
      expect(findList().exists()).toBe(true);
      expect(findDraggable().exists()).toBe(false);
    });

    it('user can drag on unassigned lane if canAdminEpic is false', () => {
      createComponent({ isUnassignedIssuesLane: true });

      expect(findList().exists()).toBe(false);
      expect(findDraggable().exists()).toBe(true);
    });
  });

  describe('drag & drop issue', () => {
    beforeEach(() => {
      createComponent({ canAdminEpic: true });
    });

    describe('handleDragOnStart', () => {
      it('adds a class `is-dragging` to document body', () => {
        expect(document.body.classList.contains('is-dragging')).toBe(false);

        wrapper.find(`[data-testid="tree-root-wrapper"]`).vm.$emit('start');

        expect(document.body.classList.contains('is-dragging')).toBe(true);
      });
    });

    describe('handleDragOnEnd', () => {
      it('removes class `is-dragging` from document body', () => {
        jest.spyOn(store, 'dispatch').mockImplementation(() => {});
        document.body.classList.add('is-dragging');

        wrapper.find(`[data-testid="tree-root-wrapper"]`).vm.$emit('end', {
          oldIndex: 1,
          newIndex: 0,
          item: {
            dataset: {
              issueId: mockIssues[0].id,
              issueIid: mockIssues[0].iid,
              issuePath: mockIssues[0].referencePath,
            },
          },
          to: { children: [], dataset: { listId: 'gid://gitlab/List/1' } },
          from: { dataset: { listId: 'gid://gitlab/List/2' } },
        });

        expect(document.body.classList.contains('is-dragging')).toBe(false);
      });
    });

    describe('highlighting', () => {
      it('scrolls to column when highlighted', async () => {
        const defaultStore = createStore();
        store = {
          ...defaultStore,
          state: {
            ...defaultStore.state,
            highlightedLists: [mockList.id],
          },
        };

        createComponent();

        await nextTick();

        expect(wrapper.element.scrollIntoView).toHaveBeenCalled();
      });
    });
  });

  describe('max issue count warning', () => {
    beforeEach(() => {
      const defaultStore = createStore();
      store = {
        ...defaultStore,
        state: {
          ...defaultStore.state,
        },
      };
    });

    describe('when issue count exceeds max issue count', () => {
      it('sets background to red-100', () => {
        createComponent({ listProps: { maxIssueCount: 3 }, totalIssuesCount: 4 });
        const block = wrapper.find('.gl-bg-red-100');
        expect(block.exists()).toBe(true);
        expect(block.attributes('class')).toContain('gl-rounded-base');
      });
    });

    describe('when list issue count does NOT exceed list max issue count', () => {
      it('does not set background to red-100', () => {
        createComponent({ listProps: { maxIssueCount: 3 }, totalIssuesCount: 2 });

        expect(wrapper.find('.gl-bg-red-100').exists()).toBe(false);
      });
    });
  });

  describe('Apollo boards', () => {
    const endDragVariables = {
      oldIndex: 1,
      newIndex: 0,
      item: {
        dataset: {
          draggableItemType: DraggableItemTypes.card,
          itemId: mockIssues[0].id,
          itemIid: mockIssues[0].iid,
          itemPath: mockIssues[0].referencePath,
        },
      },
      to: {
        children: [],
        dataset: { listId: 'gid://gitlab/List/2', epicID: 'gid://gitlab/Epic/41' },
      },
      from: { dataset: { listId: 'gid://gitlab/List/1' } },
    };

    it.each`
      isUnassignedIssuesLane | queryCalledTimes | performsQuery
      ${true}                | ${1}             | ${true}
      ${false}               | ${0}             | ${false}
    `(
      'fetches issues $performsQuery when isUnassignedIssuesLane is $isUnassignedIssuesLane',
      async ({ isUnassignedIssuesLane, queryCalledTimes }) => {
        createComponent({ isUnassignedIssuesLane, isApolloBoard: true });

        await waitForPromises();

        expect(listIssuesQueryHandlerSuccess).toHaveBeenCalledTimes(queryCalledTimes);
      },
    );

    it('sets error when fetching unassigned issues fails', async () => {
      createComponent({
        isUnassignedIssuesLane: true,
        isApolloBoard: true,
        listsIssuesQueryHandler: queryHandlerFailure,
      });

      await waitForPromises();

      expect(cacheUpdates.setError).toHaveBeenCalled();
    });

    it('calls moveIssue mutation on drag & drop card', async () => {
      createComponent({ isApolloBoard: true, canAdminEpic: true });

      await waitForPromises();

      endDrag(endDragVariables);

      await waitForPromises();

      expect(moveIssueMutationHandlerSuccess).toHaveBeenCalled();
    });

    it('sets error when moveIssue mutation fails', async () => {
      createComponent({
        isApolloBoard: true,
        canAdminEpic: true,
        moveIssueMutationHandler: queryHandlerFailure,
      });

      await waitForPromises();

      endDrag(endDragVariables);

      await waitForPromises();

      expect(cacheUpdates.setError).toHaveBeenCalled();
    });

    it('creates issue in unassigned issues lane', async () => {
      createComponent({
        listProps: {
          id: mockList.id,
        },
        isUnassignedIssuesLane: true,
        isApolloBoard: true,
        canAdminEpic: true,
      });

      await waitForPromises();

      eventHub.$emit(`toggle-issue-form-${mockList.id}`);
      await nextTick();
      expect(findNewIssueForm().exists()).toBe(true);
      findNewIssueForm().vm.$emit('addNewIssue', { title: 'Foo' });

      await nextTick();

      expect(createIssueMutationHandlerSuccess).toHaveBeenCalled();
    });

    it('sets error when creating issue in unassigned issues lane fails', async () => {
      createComponent({
        listProps: {
          id: mockList.id,
        },
        isUnassignedIssuesLane: true,
        isApolloBoard: true,
        canAdminEpic: true,
        createIssueMutationHandler: queryHandlerFailure,
      });

      await waitForPromises();

      eventHub.$emit(`toggle-issue-form-${mockList.id}`);
      await nextTick();
      expect(findNewIssueForm().exists()).toBe(true);
      findNewIssueForm().vm.$emit('addNewIssue', { title: 'Foo' });

      await waitForPromises();

      expect(cacheUpdates.setError).toHaveBeenCalled();
    });
  });
});
