import { GlButton, GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { v4 as uuid } from 'uuid';
import Api from 'ee/api';
import { STEPS } from 'ee/subscriptions/constants';
import ConfirmOrder from 'ee/subscriptions/new/components/checkout/confirm_order.vue';
import { createMockApolloProvider } from 'ee_jest/vue_shared/purchase_flow/spec_helper';
import * as googleTagManager from 'ee/google_tag_manager';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import Tracking from '~/tracking';
import { ActiveModelError } from '~/lib/utils/error_utils';
import {
  HTTP_STATUS_UNAUTHORIZED,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
} from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import createStore from 'ee/subscriptions/new/store';
import { mockInvoicePreviewBronze } from 'ee_jest/subscriptions/mock_data';

jest.mock('~/alert');
jest.mock('uuid');

describe('Confirm Order', () => {
  Vue.use(Vuex);
  Vue.use(VueApollo);

  let wrapper;
  let store;

  jest.mock('ee/api.js');

  const confirmOrderParams = {
    setup_for_company: false,
    selected_group: 123,
    new_user: false,
    customer: {
      country: 'USA',
      address_1: 'Address Line One',
      address_2: 'Address Line Two',
      city: 'San Francisco',
      state: 'California',
      zip_code: '1234',
      company: 'Org',
    },
    subscription: {
      plan_id: 'bronze_plan_id',
      payment_method_id: '123',
      quantity: 1,
      source: 'Source',
    },
  };

  const firstIdempotencyKey = 'key-1';
  const secondIdempotencyKey = 'key-2';
  const location = 'https://new-location.com';

  const initialState = {
    availablePlans: JSON.stringify([
      { code: 'bronze', name: 'Bronze Plan', id: 'bronze_plan_id' },
      { code: 'premium', name: 'Premium Plan', id: 'premium_plan_id' },
    ]),
    planId: 'bronze_plan_id',
    namespaceId: '123',
    setupForCompany: false,
    newUser: false,
    groupData: JSON.stringify([
      { fullPath: 'group-one', text: 'Group One', value: 123 },
      { fullPath: 'group-two', text: 'Group Two', value: 345 },
    ]),
  };
  const { invoicePreview } = mockInvoicePreviewBronze.data;

  const updateStoreWithSubscriptionPurchaseDetails = () => {
    store.state.invoicePreview = invoicePreview;
    store.state.paymentMethodId = '123';
    store.state.selectedPlan = 'bronze_plan_id';
    store.state.selectedGroup = 123;
    store.state.numberOfUsers = 1;
    store.state.country = 'USA';
    store.state.streetAddressLine1 = 'Address Line One';
    store.state.streetAddressLine2 = 'Address Line Two';
    store.state.city = 'San Francisco';
    store.state.countryState = 'California';
    store.state.zipCode = '1234';
    store.state.organizationName = 'Org';
    store.state.source = 'Source';
  };

  function createComponent(options = {}) {
    store = createStore(initialState);
    updateStoreWithSubscriptionPurchaseDetails();

    return shallowMount(ConfirmOrder, {
      store,
      ...options,
    });
  }

  const findConfirmButton = () => wrapper.findComponent(GlButton);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  describe('Active', () => {
    afterEach(() => {
      uuid.mockRestore();
    });

    describe('when receiving proper step data', () => {
      beforeEach(() => {
        const mockApolloProvider = createMockApolloProvider(STEPS, 3);
        wrapper = createComponent({ apolloProvider: mockApolloProvider });
      });

      it('button should be visible', () => {
        expect(findConfirmButton().exists()).toBe(true);
      });

      it('shows the text "Confirm purchase"', () => {
        expect(findConfirmButton().text()).toBe('Confirm purchase');
      });

      it('the loading indicator should not be visible', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });
    });

    describe('when changing subscription purchase details', () => {
      beforeEach(async () => {
        uuid.mockReturnValueOnce(firstIdempotencyKey).mockReturnValueOnce(secondIdempotencyKey);
        const mockApolloProvider = createMockApolloProvider(STEPS, 3);
        wrapper = createComponent({ apolloProvider: mockApolloProvider });
        await nextTick();
      });

      it.each`
        property             | value
        ${`zipCode`}         | ${'9090'}
        ${`paymentMethodId`} | ${'999'}
        ${`selectedPlan`}    | ${'premium_plan_id'}
        ${`numberOfUsers`}   | ${5}
        ${`selectedGroup`}   | ${456}
      `('regenerates idempotency key when changing $property', async ({ property, value }) => {
        store.state[property] = value;
        await nextTick();

        Api.confirmOrder = jest.fn().mockReturnValue(Promise.resolve({ data: { location } }));
        findConfirmButton().vm.$emit('click');
        await nextTick();

        expect(Api.confirmOrder).toHaveBeenLastCalledWith(
          expect.objectContaining({
            idempotency_key: secondIdempotencyKey,
          }),
        );
      });

      it.each`
        property                | value
        ${`country`}            | ${'9090'}
        ${`streetAddressLine1`} | ${'999'}
        ${`streetAddressLine2`} | ${'premium_plan_id'}
        ${`city`}               | ${5}
        ${`countryState`}       | ${456}
        ${`organizationName`}   | ${456}
      `(
        'does not regenerate idempotency key when changing $property',
        async ({ property, value }) => {
          store.state[property] = value;
          await nextTick();

          Api.confirmOrder = jest.fn().mockReturnValue(Promise.resolve({ data: { location } }));
          findConfirmButton().vm.$emit('click');
          await nextTick();

          expect(Api.confirmOrder).toHaveBeenLastCalledWith(
            expect.objectContaining({
              idempotency_key: firstIdempotencyKey,
            }),
          );
        },
      );
    });

    describe('Clicking the button', () => {
      beforeEach(async () => {
        uuid.mockReturnValue(firstIdempotencyKey);
        const mockApolloProvider = createMockApolloProvider(STEPS, 3);
        wrapper = createComponent({ apolloProvider: mockApolloProvider });
        await nextTick();

        Api.confirmOrder = jest.fn().mockReturnValue(new Promise(jest.fn()));

        findConfirmButton().vm.$emit('click');
      });

      it('calls the confirmOrder API method', () => {
        const expectedParams = {
          ...confirmOrderParams,
          idempotency_key: firstIdempotencyKey,
        };
        expect(Api.confirmOrder).toHaveBeenCalledWith(expectedParams);
      });

      it('shows the text "Confirming..."', () => {
        expect(findConfirmButton().text()).toBe('Confirming...');
      });

      it('the loading indicator should be visible', () => {
        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('button should be disabled', async () => {
        await nextTick();

        expect(findConfirmButton().attributes('disabled')).toBeDefined();
      });
    });

    describe('On confirm order success', () => {
      let trackTransactionSpy;
      let trackingSpy;

      beforeEach(async () => {
        useMockLocationHelper();
        trackingSpy = jest.spyOn(Tracking, 'event');
        trackTransactionSpy = jest.spyOn(googleTagManager, 'trackTransaction');
        uuid
          .mockReturnValueOnce(firstIdempotencyKey)
          // shouldn't have been called again
          .mockReturnValueOnce(secondIdempotencyKey);

        const mockApolloProvider = createMockApolloProvider(STEPS, 3);
        wrapper = createComponent({ apolloProvider: mockApolloProvider });
        await nextTick();

        Api.confirmOrder = jest.fn().mockReturnValue(Promise.resolve({ data: { location } }));
        findConfirmButton().vm.$emit('click');
      });

      afterEach(() => {
        trackingSpy.mockRestore();
        trackTransactionSpy.mockRestore();
      });

      it('calls trackTransaction', () => {
        expect(trackTransactionSpy).toHaveBeenCalledWith({
          paymentOption: '123',
          revenue: 48,
          tax: 0,
          selectedPlan: 'bronze_plan_id',
          quantity: 1,
        });
      });

      it('calls tracking event', () => {
        expect(trackingSpy).toHaveBeenCalledWith('default', 'click_button', {
          label: 'confirm_purchase',
          property: 'Success: subscription',
        });
      });

      it('redirects to appropriate location', () => {
        expect(window.location.assign).toHaveBeenCalledWith(location);
      });

      it('does not change the idempotency key', () => {
        expect(Api.confirmOrder).toHaveBeenLastCalledWith(
          expect.objectContaining({
            idempotency_key: firstIdempotencyKey,
          }),
        );
      });
    });

    describe('On confirm order error', () => {
      let trackingSpy;

      beforeEach(async () => {
        trackingSpy = jest.spyOn(Tracking, 'event');

        const mockApolloProvider = createMockApolloProvider(STEPS, 3);
        wrapper = createComponent({ apolloProvider: mockApolloProvider });
        await nextTick();
      });

      describe('when response has name', () => {
        beforeEach(() => {
          Api.confirmOrder = jest
            .fn()
            .mockReturnValue(Promise.resolve({ data: { name: ['Error_1', "Error ' 2"] } }));
          findConfirmButton().vm.$emit('click');
        });

        it('emits error event with appropriate error', () => {
          expect(wrapper.emitted('error')).toEqual([
            [new ActiveModelError(null, '"Name: Error_1, Error \' 2"')],
          ]);
        });

        it('calls tracking event', () => {
          expect(trackingSpy).toHaveBeenCalledWith('default', 'click_button', {
            label: 'confirm_purchase',
            property: "Name: Error_1, Error ' 2",
          });
        });
      });

      describe('when response has non promo code related errors', () => {
        const errors = 'Errorororor';
        beforeEach(() => {
          Api.confirmOrder = jest.fn().mockReturnValue(Promise.resolve({ data: { errors } }));
          findConfirmButton().vm.$emit('click');
        });

        it('emits error event with appropriate error', () => {
          expect(wrapper.emitted('error')).toEqual([[new ActiveModelError(null, `"${errors}"`)]]);
        });

        it('calls tracking event', () => {
          expect(trackingSpy).toHaveBeenCalledWith('default', 'click_button', {
            label: 'confirm_purchase',
            property: errors,
          });
        });
      });

      describe('when response has promo code errors', () => {
        const errors = {
          message: 'Promo code is invalid',
          attributes: ['promo_code'],
          code: 'INVALID',
        };
        beforeEach(() => {
          Api.confirmOrder = jest.fn().mockReturnValue(Promise.resolve({ data: { errors } }));
          findConfirmButton().vm.$emit('click');
        });

        it('emits error event with appropriate error', () => {
          expect(wrapper.emitted('error')).toEqual([
            [new ActiveModelError(null, '"Promo code is invalid"')],
          ]);
        });

        it('calls tracking event', () => {
          expect(trackingSpy).toHaveBeenCalledWith('default', 'click_button', {
            label: 'confirm_purchase',
            property: 'Promo code is invalid',
          });
        });
      });

      describe('when response has error attribute map', () => {
        const errors = { email: ["can't be blank"] };
        const errorAttributeMap = { email: ['taken'] };

        beforeEach(() => {
          Api.confirmOrder = jest
            .fn()
            .mockReturnValue(
              Promise.resolve({ data: { errors, error_attribute_map: errorAttributeMap } }),
            );
          findConfirmButton().vm.$emit('click');
        });

        it('emits error event with appropriate error', () => {
          expect(wrapper.emitted('error')).toEqual([
            [new ActiveModelError(errorAttributeMap, JSON.stringify(errors))],
          ]);
        });

        it('calls tracking event', () => {
          expect(trackingSpy).toHaveBeenCalledWith('default', 'click_button', {
            label: 'confirm_purchase',
            property: errors,
          });
        });
      });

      afterEach(() => {
        trackingSpy.mockRestore();
      });
    });

    describe('On confirm order failure', () => {
      let trackingSpy;
      const error = new Error('Request failed with status code 500');

      useMockLocationHelper();

      beforeEach(async () => {
        trackingSpy = jest.spyOn(Tracking, 'event');
        uuid.mockReturnValueOnce(firstIdempotencyKey).mockReturnValueOnce(secondIdempotencyKey);

        const mockApolloProvider = createMockApolloProvider(STEPS, 3);
        wrapper = createComponent({ apolloProvider: mockApolloProvider });
        await nextTick();
      });

      it('calls tracking event', async () => {
        Api.confirmOrder = jest.fn().mockRejectedValue(error);

        findConfirmButton().vm.$emit('click');
        await waitForPromises();

        expect(trackingSpy).toHaveBeenCalledWith('default', 'click_button', {
          label: 'confirm_purchase',
          property: 'Request failed with status code 500',
        });
      });

      it('emits error event', async () => {
        Api.confirmOrder = jest.fn().mockRejectedValue(error);

        findConfirmButton().vm.$emit('click');
        await waitForPromises();

        expect(wrapper.emitted('error')).toEqual([[error]]);
      });

      it('changes the idempotency key for client error', async () => {
        Api.confirmOrder = jest
          .fn()
          // Attempt 1 - server error
          .mockRejectedValueOnce({ response: { status: HTTP_STATUS_INTERNAL_SERVER_ERROR } })
          // Attempt 2 - client error
          .mockRejectedValueOnce({ response: { status: HTTP_STATUS_UNAUTHORIZED } })
          // Attempt 3 - success
          .mockResolvedValue({ data: { location } });

        // Attempt 1
        findConfirmButton().vm.$emit('click');
        await waitForPromises();
        expect(Api.confirmOrder).toHaveBeenNthCalledWith(
          1,
          expect.objectContaining({
            idempotency_key: firstIdempotencyKey,
          }),
        );

        // Attempt 2 - Generates idempotency key after HTTP_STATUS_UNAUTHORIZED
        findConfirmButton().vm.$emit('click');
        await waitForPromises();
        expect(Api.confirmOrder).toHaveBeenNthCalledWith(
          2,
          expect.objectContaining({
            idempotency_key: firstIdempotencyKey,
          }),
        );
        // Attempt 3 - Invokes `confirmOrder` the last time
        findConfirmButton().vm.$emit('click');
        await waitForPromises();
        expect(Api.confirmOrder).toHaveBeenLastCalledWith(
          expect.objectContaining({
            idempotency_key: secondIdempotencyKey,
          }),
        );

        expect(Api.confirmOrder).toHaveBeenCalledTimes(3);
      });

      it('does not change the idempotency key for server error', async () => {
        Api.confirmOrder = jest
          .fn()
          // Attempt 1 - server error
          .mockRejectedValueOnce({ response: { status: HTTP_STATUS_INTERNAL_SERVER_ERROR } })
          // Attempt 2 - success
          .mockResolvedValue({ data: { location } });

        // Attempt 1
        findConfirmButton().vm.$emit('click');
        await waitForPromises();
        expect(Api.confirmOrder).toHaveBeenNthCalledWith(
          1,
          expect.objectContaining({
            idempotency_key: firstIdempotencyKey,
          }),
        );

        // Attempt 2
        findConfirmButton().vm.$emit('click');
        await waitForPromises();
        expect(Api.confirmOrder).toHaveBeenLastCalledWith(
          expect.objectContaining({
            idempotency_key: firstIdempotencyKey,
          }),
        );
      });

      afterEach(() => {
        trackingSpy.mockRestore();
      });
    });

    describe('Button state', () => {
      const mockApolloProvider = createMockApolloProvider(STEPS, 3);

      it('should be enabled when not confirming and has valid price details', () => {
        wrapper = createComponent({ apolloProvider: mockApolloProvider });

        expect(findConfirmButton().attributes('disabled')).toBe(undefined);
      });

      it('should be disabled when confirming and has valid price details', async () => {
        // Return unresolved promise to simulate loading state
        Api.confirmOrder = jest.fn().mockReturnValue(new Promise(() => {}));
        wrapper = createComponent({ apolloProvider: mockApolloProvider });

        findConfirmButton().vm.$emit('click');
        await nextTick();

        expect(findConfirmButton().attributes('disabled')).toBeDefined();
      });

      it('should be disabled when not confirming and has invalid price details', async () => {
        wrapper = createComponent({ apolloProvider: mockApolloProvider });
        store.state.invoicePreview = null;
        await nextTick();

        expect(findConfirmButton().attributes('disabled')).toBeDefined();
      });
    });
  });

  describe('Inactive', () => {
    beforeEach(() => {
      const mockApolloProvider = createMockApolloProvider(STEPS, 1);
      wrapper = createComponent({ apolloProvider: mockApolloProvider });
    });

    it('button should not be visible', () => {
      expect(findConfirmButton().exists()).toBe(false);
    });
  });
});
