import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';
import Tracking from '~/tracking';
import { visitUrl } from '~/lib/utils/url_utility';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { createMockClient } from 'helpers/mock_apollo_helper';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('StatisticsSeatsCard', () => {
  let wrapper;
  const purchaseButtonLink = 'https://gitlab.com/purchase-more-seats';
  const defaultProps = {
    seatsUsed: 20,
    seatsOwed: 5,
    namespaceId: '4321',
    purchaseButtonLink,
  };

  const defaultApolloData = {
    subscription: { canAddSeats: true, canRenew: true, communityPlan: false },
    userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
  };

  const createComponent = (options = {}) => {
    const { props = {}, apolloData = defaultApolloData } = options;

    const queryHandlerMock = jest.fn().mockResolvedValue({
      data: apolloData,
    });
    const mockCustomersDotClient = createMockClient([
      [getSubscriptionPermissionsData, queryHandlerMock],
    ]);
    const mockGitlabClient = createMockClient();
    const mockApollo = new VueApollo({
      defaultClient: mockGitlabClient,
      clients: { customersDotClient: mockCustomersDotClient, gitlabClient: mockGitlabClient },
    });

    wrapper = shallowMountExtended(StatisticsSeatsCard, {
      propsData: { ...defaultProps, ...props },
      apolloProvider: mockApollo,
      stubs: {
        LimitedAccessModal,
      },
    });
  };

  const findSeatsUsedBlock = () => wrapper.findByTestId('seats-used');
  const findSeatsOwedBlock = () => wrapper.findByTestId('seats-owed');
  const findPurchaseButton = () => wrapper.findByTestId('purchase-button');
  const findLimitedAccessModal = () => wrapper.findComponent(LimitedAccessModal);

  describe('when `isLoading` computed value is `true`', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders `GlSkeletonLoader`', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });
  });

  describe('seats used block', () => {
    it('renders seats used block if seatsUsed is passed', async () => {
      createComponent();

      // wait for apollo to load
      await waitForPromises();

      const seatsUsedBlock = findSeatsUsedBlock();

      expect(seatsUsedBlock.exists()).toBe(true);
      expect(seatsUsedBlock.text()).toContain('20');
      expect(seatsUsedBlock.findComponent(GlLink).exists()).toBe(true);
    });

    it('does not render seats used block if seatsUsed is not passed', async () => {
      createComponent({ props: { seatsUsed: null } });

      // wait for apollo to load
      await waitForPromises();

      expect(findSeatsUsedBlock().exists()).toBe(false);
    });
  });

  describe('seats owed block', () => {
    it('renders seats owed block if seatsOwed is passed', async () => {
      createComponent();

      // wait for apollo to load
      await waitForPromises();

      const seatsOwedBlock = findSeatsOwedBlock();

      expect(seatsOwedBlock.exists()).toBe(true);
      expect(seatsOwedBlock.text()).toContain('5');
      expect(seatsOwedBlock.findComponent(GlLink).exists()).toBe(true);
    });

    it('does not render seats owed block if seatsOwed is not passed', async () => {
      createComponent({ props: { seatsOwed: null } });

      // wait for apollo to load
      await waitForPromises();

      expect(findSeatsOwedBlock().exists()).toBe(false);
    });
  });

  describe('purchase button', () => {
    it('renders purchase button if purchase link and purchase text is passed', async () => {
      createComponent();

      // wait for apollo to load
      await waitForPromises();

      const purchaseButton = findPurchaseButton();

      expect(purchaseButton.exists()).toBe(true);
    });

    it('does not render purchase button if purchase link is not passed', async () => {
      createComponent({ props: { purchaseButtonLink: null } });

      // wait for apollo to load
      await waitForPromises();

      expect(findPurchaseButton().exists()).toBe(false);
    });

    it('tracks event', async () => {
      jest.spyOn(Tracking, 'event');
      createComponent();

      // wait for apollo to load
      await waitForPromises();

      findPurchaseButton().vm.$emit('click');

      expect(Tracking.event).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'add_seats_saas',
        property: 'usage_quotas_page',
      });
    });

    it('redirects when clicked', async () => {
      createComponent();

      // wait for apollo to load
      await waitForPromises();

      findPurchaseButton().vm.$emit('click');

      expect(visitUrl).toHaveBeenCalledWith('https://gitlab.com/purchase-more-seats');
    });

    it('does not render purchase button if communityPlan is true', async () => {
      createComponent({
        apolloData: {
          subscription: { canAddSeats: false, canRenew: true, communityPlan: true },
          userActionAccess: { limitedAccessReason: 'INVALID_REASON' },
        },
      });
      await waitForPromises();

      expect(findPurchaseButton().exists()).toBe(false);
    });
  });

  describe('limited access modal', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    describe('when limitedAccessModal FF is on', () => {
      beforeEach(() => {
        gon.features = { limitedAccessModal: true };
      });

      describe.each`
        canAddSeats | limitedAccessReason
        ${false}    | ${'MANAGED_BY_RESELLER'}
        ${false}    | ${'RAMP_SUBSCRIPTION'}
      `(
        'when canAddSeats=$canAddSeats and limitedAccessReason=$limitedAccessReason',
        ({ canAddSeats, limitedAccessReason }) => {
          beforeEach(async () => {
            createComponent({
              apolloData: {
                subscription: { canAddSeats, canRenew: true, communityPlan: false },
                userActionAccess: { limitedAccessReason },
              },
            });
            await waitForPromises();

            findPurchaseButton().vm.$emit('click');
            await nextTick();
          });

          it('shows modal', () => {
            expect(findLimitedAccessModal().isVisible()).toBe(true);
          });

          it('sends correct props', () => {
            expect(findLimitedAccessModal().props('limitedAccessReason')).toBe(limitedAccessReason);
          });

          it('does not navigate to URL', () => {
            expect(visitUrl).not.toHaveBeenCalled();
          });
        },
      );

      describe.each`
        canAddSeats | limitedAccessReason
        ${false}    | ${'INVALID_REASON'}
        ${true}     | ${'MANAGED_BY_RESELLER'}
        ${true}     | ${'RAMP_SUBSCRIPTION'}
      `(
        'when canAddSeats=$canAddSeats and limitedAccessReason=$limitedAccessReason',
        ({ canAddSeats, limitedAccessReason }) => {
          beforeEach(async () => {
            createComponent({
              apolloData: {
                subscription: { canAddSeats, canRenew: true, communityPlan: false },
                userActionAccess: { limitedAccessReason },
              },
            });
            await waitForPromises();

            findPurchaseButton().vm.$emit('click');
            await nextTick();
          });

          it('does not show modal', () => {
            expect(findLimitedAccessModal().exists()).toBe(false);
          });

          it('navigates to URL', () => {
            expect(visitUrl).toHaveBeenCalledWith(purchaseButtonLink);
          });
        },
      );
    });

    describe('when limitedAccessModal FF is off', () => {
      beforeEach(async () => {
        gon.features = { limitedAccessModal: false };
        createComponent();

        // wait for apollo to load
        await waitForPromises();

        findPurchaseButton().vm.$emit('click');
        await nextTick();
      });

      it('does not show modal', () => {
        expect(findLimitedAccessModal().exists()).toBe(false);
      });

      it('navigates to URL', () => {
        expect(visitUrl).toHaveBeenCalledWith('https://gitlab.com/purchase-more-seats');
      });
    });
  });
});
