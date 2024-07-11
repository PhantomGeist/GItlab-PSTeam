import { GlLabel, GlTooltip } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import IssueCardWeight from 'ee/boards/components/issue_card_weight.vue';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import BoardCardInner from '~/boards/components/board_card_inner.vue';
import isShowingLabelsQuery from '~/graphql_shared/client/is_showing_labels.query.graphql';
import { TYPE_ISSUE } from '~/issues/constants';

Vue.use(VueApollo);

describe('Board card component', () => {
  let wrapper;
  let issue;
  let list;
  let store;

  const findEpicCountablesTotalTooltip = () => wrapper.findComponent(GlTooltip);
  const findEpicCountables = () => wrapper.findByTestId('epic-countables');
  const findEpicCountablesBadgeIssues = () => wrapper.findByTestId('epic-countables-counts-issues');
  const findEpicCountablesBadgeWeight = () => wrapper.findByTestId('epic-countables-weight-issues');
  const findEpicBadgeProgress = () => wrapper.findByTestId('epic-progress');
  const findEpicCountablesTotalWeight = () => wrapper.findByTestId('epic-countables-total-weight');
  const findEpicProgressTooltip = () => wrapper.findByTestId('epic-progress-tooltip-content');

  const mockApollo = createMockApollo();

  const createComponent = ({ props = {}, isShowingLabels = true, isEpicBoard = false } = {}) => {
    mockApollo.clients.defaultClient.cache.writeQuery({
      query: isShowingLabelsQuery,
      data: {
        isShowingLabels,
      },
    });

    wrapper = mountExtended(BoardCardInner, {
      store,
      apolloProvider: mockApollo,
      propsData: {
        list,
        item: issue,
        index: 0,
        ...props,
      },
      provide: {
        groupId: null,
        rootPath: '/',
        scopedLabelsAvailable: false,
        isEpicBoard,
        allowSubEpics: isEpicBoard,
        issuableType: TYPE_ISSUE,
        isGroupBoard: true,
        isApolloBoard: false,
      },
    });
  };

  beforeEach(() => {
    list = {
      id: 300,
      position: 0,
      title: 'Test',
      listType: 'label',
      label: {
        id: 5000,
        title: 'Testing',
        color: '#ff0000',
        description: 'testing;',
        textColor: 'white',
      },
    };

    issue = {
      title: 'Testing',
      id: 1,
      iid: 1,
      confidential: false,
      labels: [list.label],
      assignees: [],
      referencePath: '#1',
      webUrl: '/test/1',
      weight: 1,
      blocked: true,
      blockedByCount: 2,
      healthStatus: 'onTrack',
    };
  });

  describe('labels', () => {
    beforeEach(() => {
      const label1 = {
        id: 3,
        title: 'testing 123',
        color: '#000cff',
        textColor: 'white',
        description: 'test',
      };

      issue.labels = [...issue.labels, label1];
    });

    it.each`
      type              | title              | desc
      ${'GroupLabel'}   | ${'Group label'}   | ${'shows group labels on group boards'}
      ${'ProjectLabel'} | ${'Project label'} | ${'shows project labels on group boards'}
    `('$desc', ({ type, title }) => {
      issue.labels = [
        ...issue.labels,
        {
          id: 9001,
          type,
          title,
          color: '#000000',
        },
      ];

      createComponent({ props: { groupId: 1 } });

      expect(wrapper.findAllComponents(GlLabel)).toHaveLength(3);
      expect(wrapper.findComponent(GlLabel).props('title')).toContain(title);
    });

    it('shows no labels when the isShowingLabels is false', () => {
      createComponent({ isShowingLabels: false });

      expect(wrapper.findAll('.board-card-labels')).toHaveLength(0);
    });
  });

  describe('weight', () => {
    it('shows weight component', () => {
      createComponent();

      expect(wrapper.findComponent(IssueCardWeight).exists()).toBe(true);
    });
  });

  describe('health status', () => {
    it('shows healthStatus component', () => {
      createComponent();

      expect(wrapper.findComponent(IssueHealthStatus).props('healthStatus')).toBe('onTrack');
    });
  });

  describe('Epic board', () => {
    const descendantCounts = {
      closedEpics: 0,
      closedIssues: 0,
      openedEpics: 0,
      openedIssues: 0,
    };

    const descendantWeightSum = {
      closedIssues: 0,
      openedIssues: 0,
    };

    it('should render if the item has issues', () => {
      createComponent({
        props: {
          item: {
            ...issue,
            descendantCounts: {
              ...descendantCounts,
              openedIssues: 1,
            },
            descendantWeightSum,
          },
        },
        isEpicBoard: true,
      });

      expect(findEpicCountables().exists()).toBe(true);
    });

    it('should not render if the item does not have issues', () => {
      createComponent({
        item: {
          ...issue,
          descendantCounts,
          descendantWeightSum,
        },
      });

      expect(findEpicCountablesBadgeIssues().exists()).toBe(false);
    });

    it('shows render item countBadge, weights, and progress correctly', () => {
      createComponent({
        props: {
          item: {
            ...issue,
            descendantCounts: {
              ...descendantCounts,
              openedIssues: 1,
            },
            descendantWeightSum: {
              closedIssues: 10,
              openedIssues: 5,
            },
          },
        },
        isEpicBoard: true,
      });

      expect(findEpicCountablesBadgeIssues().text()).toBe('1');
      expect(findEpicCountablesBadgeWeight().text()).toBe('15');
      expect(findEpicBadgeProgress().text()).toBe('67%');
    });

    it('does not render progress when weight is zero', () => {
      createComponent({
        props: {
          item: {
            ...issue,
            descendantCounts: {
              ...descendantCounts,
              openedIssues: 1,
            },
            descendantWeightSum,
          },
        },
        isEpicBoard: true,
      });

      expect(findEpicBadgeProgress().exists()).toBe(false);
    });

    it('renders the tooltip with the correct data', () => {
      createComponent({
        props: {
          item: {
            ...issue,
            descendantCounts: {
              ...descendantCounts,
              openedIssues: 1,
              closedIssues: 1,
            },
            descendantWeightSum: {
              closedIssues: 10,
              openedIssues: 5,
            },
          },
        },
        isEpicBoard: true,
      });

      const tooltip = findEpicCountablesTotalTooltip();
      expect(tooltip).toBeDefined();

      expect(findEpicCountablesTotalWeight().text()).toBe('15');
      expect(findEpicBadgeProgress().exists()).toBe(true);
      expect(findEpicProgressTooltip().text()).toBe('10 of 15 weight completed');
    });
  });
});
