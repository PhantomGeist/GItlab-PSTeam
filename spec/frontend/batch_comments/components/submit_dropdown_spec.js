import { GlDisclosureDropdown } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SubmitDropdown from '~/batch_comments/components/submit_dropdown.vue';
import { mockTracking } from 'helpers/tracking_helper';
import userCanApproveQuery from '~/batch_comments/queries/can_approve.query.graphql';

jest.mock('~/autosave');

Vue.use(VueApollo);
Vue.use(Vuex);

let wrapper;
let publishReview;
let trackingSpy;

function factory({ canApprove = true, shouldAnimateReviewButton = false } = {}) {
  publishReview = jest.fn();
  trackingSpy = mockTracking(undefined, null, jest.spyOn);
  const requestHandlers = [
    [
      userCanApproveQuery,
      () =>
        Promise.resolve({
          data: {
            project: {
              id: 1,
              mergeRequest: {
                id: 1,
                userPermissions: {
                  canApprove,
                },
              },
            },
          },
        }),
    ],
  ];
  const apolloProvider = createMockApollo(requestHandlers);

  const store = new Vuex.Store({
    getters: {
      getNotesData: () => ({
        markdownDocsPath: '/markdown/docs',
        quickActionsDocsPath: '/quickactions/docs',
      }),
      getNoteableData: () => ({
        id: 1,
        preview_note_path: '/preview',
      }),
      noteableType: () => 'merge_request',
      getCurrentUserLastNote: () => ({ id: 1 }),
    },
    modules: {
      diffs: {
        namespaced: true,
        state: {
          projectPath: 'gitlab-org/gitlab',
        },
      },
      batchComments: {
        namespaced: true,
        state: { shouldAnimateReviewButton },
        actions: {
          publishReview,
        },
      },
    },
  });
  wrapper = mountExtended(SubmitDropdown, {
    store,
    apolloProvider,
  });
}

const findCommentTextarea = () => wrapper.findByTestId('comment-textarea');
const findSubmitButton = () => wrapper.findByTestId('submit-review-button');
const findForm = () => wrapper.findByTestId('submit-gl-form');
const findSubmitDropdown = () => wrapper.findComponent(GlDisclosureDropdown);

describe('Batch comments submit dropdown', () => {
  afterEach(() => {
    window.mrTabs = null;
  });

  it('calls publishReview with note data', async () => {
    factory();

    findCommentTextarea().setValue('Hello world');

    await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

    expect(publishReview).toHaveBeenCalledWith(expect.anything(), {
      noteable_type: 'merge_request',
      noteable_id: 1,
      note: 'Hello world',
      approve: false,
      approval_password: '',
    });
  });

  it('tracks submit action', () => {
    factory();

    findCommentTextarea().setValue('Hello world');

    findForm().vm.$emit('submit', { preventDefault: jest.fn() });

    expect(trackingSpy).toHaveBeenCalledWith(undefined, 'save_markdown', {
      label: 'markdown_editor',
      property: 'MergeRequest_review',
    });
  });

  it('switches to the overview tab after submit', async () => {
    window.mrTabs = { tabShown: jest.fn() };

    factory();

    findCommentTextarea().setValue('Hello world');

    await findForm().vm.$emit('submit', { preventDefault: jest.fn() });
    await Vue.nextTick();

    expect(window.mrTabs.tabShown).toHaveBeenCalledWith('show');
  });

  it('sets submit dropdown to loading', async () => {
    factory();

    findCommentTextarea().setValue('Hello world');

    await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

    expect(findSubmitButton().props('loading')).toBe(true);
  });

  it.each`
    canApprove | exists   | existsText
    ${true}    | ${true}  | ${'shows'}
    ${false}   | ${false} | ${'hides'}
  `(
    '$existsText approve checkbox if can_approve is $canApprove',
    async ({ canApprove, exists }) => {
      factory({ canApprove });

      wrapper.findComponent(GlDisclosureDropdown).vm.$emit('shown');

      await waitForPromises();

      expect(wrapper.findByTestId('approve_merge_request').exists()).toBe(exists);
    },
  );

  it.each`
    shouldAnimateReviewButton | animationClassApplied | classText
    ${true}                   | ${true}               | ${'applies'}
    ${false}                  | ${false}              | ${'does not apply'}
  `(
    '$classText animation class to `Finish review` button if `shouldAnimateReviewButton` is $shouldAnimateReviewButton',
    ({ shouldAnimateReviewButton, animationClassApplied }) => {
      factory({ shouldAnimateReviewButton });

      expect(findSubmitDropdown().classes('submit-review-dropdown-animated')).toBe(
        animationClassApplied,
      );
    },
  );
});
