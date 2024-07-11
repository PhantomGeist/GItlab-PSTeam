import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';
import GenerateTestFileDrawer from 'ee/ai/components/generate_test_file_drawer.vue';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import testFileGeneratorMutation from 'ee/ai/graphql/test_file_generator.mutation.graphql';

Vue.use(VueApollo);
Vue.config.ignoredElements = ['copy-code'];

let wrapper;
let subscriptionHandlerMock;
let mutationHandlerMock;

function createComponent() {
  const apolloProvider = createMockApollo([
    [aiResponseSubscription, subscriptionHandlerMock],
    [testFileGeneratorMutation, mutationHandlerMock],
  ]);

  wrapper = mountExtended(GenerateTestFileDrawer, {
    propsData: {
      resourceId: 'gid://gitlab/MergeRequest/1',
      filePath: 'index.js',
    },
    apolloProvider,
  });
}

const subscriptionResponsePartial = {
  id: '123',
  requestId: '123',
  role: GENIE_CHAT_MODEL_ROLES.assistant,
  timestamp: '2021-05-26T14:00:00.000Z',
  type: null,
  chunkId: null,
  extras: null,
};

describe('Generate test file drawer component', () => {
  beforeEach(() => {
    window.gon.current_user_id = 1;
    mutationHandlerMock = jest
      .fn()
      .mockResolvedValue({ data: { aiAction: { errors: [], __typename: 'AiActionPayload' } } });
    subscriptionHandlerMock = jest.fn().mockResolvedValue({
      data: {
        aiCompletionResponse: {
          content: `
            \`\`\`
            puts "This is test code"
            \`\`\`
          `,
          contentHtml: `<pre><code>puts "This is test code"</code></pre>`,
          errors: [],
          ...subscriptionResponsePartial,
        },
      },
    });
  });

  afterEach(() => {
    mutationHandlerMock.mockRestore();
    subscriptionHandlerMock.mockRestore();
  });

  it('calls mutation when mounted', () => {
    createComponent();

    expect(mutationHandlerMock).toHaveBeenCalledWith({
      filePath: 'index.js',
      resourceId: 'gid://gitlab/MergeRequest/1',
    });
  });

  it('calls subscription', () => {
    createComponent();

    expect(subscriptionHandlerMock).toHaveBeenCalledWith({
      resourceId: 'gid://gitlab/MergeRequest/1',
      userId: 'gid://gitlab/User/1',
      htmlResponse: true,
    });
  });

  it('shows loading state when subscription is loading', () => {
    createComponent();

    expect(wrapper.findByTestId('generate-test-loading-state').exists()).toBe(true);
  });

  it('renders returned test from subscription', async () => {
    createComponent();

    await waitForPromises();

    expect(wrapper.findByTestId('generate-test-code').text()).toContain('puts "This is test code"');
  });

  it('emits close event when closed', () => {
    createComponent();

    wrapper.find('.gl-drawer-close-button').vm.$emit('click');

    expect(wrapper.emitted().close).toBeDefined();
  });

  it('renders alert when test could not be generated', async () => {
    subscriptionHandlerMock = jest.fn().mockResolvedValue({
      data: {
        aiCompletionResponse: {
          content: 'As the file does not contain any code',
          contentHtml: 'As the file does not contain any code',
          errors: [],
          ...subscriptionResponsePartial,
        },
      },
    });

    createComponent();

    await waitForPromises();

    expect(wrapper.findComponent(GlAlert).text()).toContain(
      'Unable to generate tests for specified file.',
    );
  });
});
