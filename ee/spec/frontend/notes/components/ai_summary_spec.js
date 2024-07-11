import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import { GlBadge, GlIcon, GlSkeletonLoader } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import AiSummary from 'ee/notes/components/ai_summary.vue';
import { createAlert } from '~/alert';
import { getMarkdown } from '~/rest_api';
import waitForPromises from 'helpers/wait_for_promises';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import { i18n } from 'ee/ai/constants';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/rest_api');

const showToast = jest.fn();
const mocks = {
  $toast: {
    show: showToast,
  },
};

describe('AiSummary component', () => {
  let wrapper;
  let aiResponseSubscriptionHandler;
  const resourceGlobalId = 'gid://gitlab/Issue/1';
  const userId = 99;
  const LONGER_THAN_MAX_REQUEST_TIMEOUT = 1000 * 20; // 20 seconds

  const findMarkdownRef = () => wrapper.findComponent({ ref: 'markdown' });
  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findIcon = (name) =>
    wrapper.findAllComponents(GlIcon).filter((icon) => icon.props().name === name);
  const findCopyButton = () => wrapper.find('[data-testid="copy-ai-summary"]');
  const findRemoveButton = () => wrapper.find('[data-testid="remove-ai-summary"]');

  const createWrapper = (props = { aiLoading: true }) => {
    window.gon = { current_user_id: userId };

    aiResponseSubscriptionHandler = createMockSubscription();
    const mockApollo = createMockApollo();
    mockApollo.defaultClient.setRequestHandler(
      aiResponseSubscription,
      () => aiResponseSubscriptionHandler,
    );

    wrapper = mountExtended(AiSummary, {
      apolloProvider: mockApollo,
      provide: {
        resourceGlobalId,
      },
      mocks,
      propsData: props,
    });
  };

  describe('aiLoading', () => {
    it('shows only skeleton loader while loading', () => {
      createWrapper();

      expect(findSkeleton().exists()).toBe(true);
      expect(findIcon('eye-slash').exists()).toBe(false);
      expect(wrapper.text()).not.toContain('Only visible to you');
    });

    it('shows alert if request times out', () => {
      createWrapper();

      jest.advanceTimersByTime(LONGER_THAN_MAX_REQUEST_TIMEOUT);

      expect(createAlert).toHaveBeenCalled();
    });
  });

  describe('loaded', () => {
    beforeEach(async () => {
      getMarkdown.mockResolvedValueOnce({ data: { html: 'yes' } });
      createWrapper();
      await waitForPromises();

      aiResponseSubscriptionHandler.next({
        data: {
          aiCompletionResponse: {
            content: '**yay**',
          },
        },
      });

      wrapper.setProps({ aiLoading: false });
    });

    it('does not timeout once it has received a successful response', async () => {
      await waitForPromises();
      jest.advanceTimersByTime(LONGER_THAN_MAX_REQUEST_TIMEOUT);

      expect(createAlert).not.toHaveBeenCalled();
    });

    it('shows "AI-generated summary"', () => {
      expect(findIcon('tanuki-ai').exists()).toBe(true);
      expect(findBadge().text()).toBe(i18n.EXPERIMENT_BADGE);
      expect(wrapper.text()).toContain('AI-generated summary');
    });

    it('shows the response in a markdown block', () => {
      expect(findMarkdownRef().text()).toContain('yes');
    });

    it('shows "Only visible to you"', () => {
      expect(findIcon('eye-slash').exists()).toBe(true);
      expect(wrapper.text()).toContain('Only visible to you');
    });

    it('can copy summary text to clipboard', () => {
      expect(findCopyButton().attributes('data-clipboard-text')).toBe('**yay**');

      findCopyButton().vm.$emit('action');

      expect(showToast).toHaveBeenCalledWith('Copied');
    });

    it('can remove summary from button', async () => {
      findRemoveButton().vm.$emit('action');

      await nextTick();

      expect(wrapper.text()).toBe('');
    });
  });
});
