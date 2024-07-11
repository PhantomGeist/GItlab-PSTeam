import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlDisclosureDropdown } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SubmitDropdown from '~/batch_comments/components/submit_dropdown.vue';
import userCanApproveQuery from '~/batch_comments/queries/can_approve.query.graphql';

Vue.use(Vuex);
Vue.use(VueApollo);

let wrapper;
let publishReview;

function factory({ canApprove = true, requirePasswordToApprove = true } = {}) {
  publishReview = jest.fn();
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
        require_password_to_approve: requirePasswordToApprove,
      }),
      noteableType: () => 'merge_request',
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

describe('Batch comments submit dropdown', () => {
  it.each`
    requirePasswordToApprove | exists   | existsText
    ${true}                  | ${true}  | ${'shows'}
    ${false}                 | ${false} | ${'hides'}
  `(
    '$existsText approve password if require_password_to_approve is $requirePasswordToApprove',
    async ({ requirePasswordToApprove, exists }) => {
      factory({ requirePasswordToApprove });

      wrapper.findComponent(GlDisclosureDropdown).vm.$emit('shown');

      await waitForPromises();

      expect(wrapper.findByTestId('approve_password').exists()).toBe(exists);
    },
  );
});
