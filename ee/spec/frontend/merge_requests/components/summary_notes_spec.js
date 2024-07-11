import { GlIntersectionObserver } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import summaryNotesQuery from 'ee/merge_requests/queries/summary_notes.query.graphql';
import SummaryNotes, {
  summaryState,
  INITIAL_STATE,
} from 'ee/merge_requests/components/summary_notes.vue';

Vue.use(VueApollo);

let wrapper;
let mockSummaryNotesQuery;

function createComponent({
  diffLlmSummary = { content: 'AI summary', createdAt: 'created-at' },
  reviewSummaries = [],
} = {}) {
  mockSummaryNotesQuery = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: '1',
        mergeRequest: {
          id: '1',
          mergeRequestDiffs: {
            pageInfo: {
              endCursor: 'end',
              hasNextPage: true,
            },
            nodes: [
              {
                diffLlmSummary,
                reviewLlmSummaries: {
                  nodes: reviewSummaries,
                },
              },
            ],
          },
        },
      },
    },
  });

  const mockApollo = createMockApollo([[summaryNotesQuery, mockSummaryNotesQuery]]);

  wrapper = shallowMountExtended(SummaryNotes, { apolloProvider: mockApollo });
}

describe('Merge request summary notes component', () => {
  afterEach(() => {
    Object.keys(INITIAL_STATE).forEach((k) => {
      summaryState[k] = INITIAL_STATE[k];
    });
  });

  it('renders list of diff summaries', async () => {
    summaryState.toggleOpen();

    createComponent();

    await waitForPromises();

    expect(wrapper.findAllByTestId('summary-note').length).toBe(1);
    expect(wrapper.findAllByTestId('summary-note').at(0).props()).toEqual({
      summary: { content: 'AI summary', createdAt: 'created-at', children: [] },
      level: 1,
    });
  });

  it('renders list of review summaries', async () => {
    const reviewSummaries = [
      {
        contentHtml: 'review',
        createdAt: 'created-at',
        reviewer: { webUrl: 'https://gitlab.com' },
      },
    ];

    summaryState.toggleOpen();

    createComponent({ reviewSummaries, diffLlmSummary: null });

    await waitForPromises();

    expect(wrapper.findAllByTestId('summary-note').length).toBe(1);
    expect(wrapper.findAllByTestId('summary-note').at(0).props()).toEqual({
      summary: {
        contentHtml: 'review',
        createdAt: 'created-at',
        reviewer: { webUrl: 'https://gitlab.com' },
      },
      level: 1,
    });
  });

  it('renders list of review summaries without diff summary', async () => {
    const reviewSummaries = [
      {
        contentHtml: 'review',
        createdAt: 'created-at',
        reviewer: { webUrl: 'https://gitlab.com' },
      },
    ];

    summaryState.toggleOpen();

    createComponent({ reviewSummaries });

    await waitForPromises();

    expect(wrapper.findAllByTestId('summary-note').length).toBe(1);
    expect(wrapper.findAllByTestId('summary-note').at(0).props()).toEqual({
      summary: { content: 'AI summary', createdAt: 'created-at', children: reviewSummaries },
      level: 1,
    });
  });

  it('fetches more', async () => {
    summaryState.toggleOpen();

    createComponent();

    await waitForPromises();

    wrapper.findComponent(GlIntersectionObserver).vm.$emit('appear');

    expect(mockSummaryNotesQuery.mock.calls.length).toBe(2);
    expect(mockSummaryNotesQuery.mock.calls[1][0]).toEqual({
      after: 'end',
      iid: '',
      projectPath: '',
    });
  });
});
