<script>
import { GlButton, GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { v4 as uuidv4 } from 'uuid';
import { isEqual } from 'lodash';
import { STEPS } from 'ee/subscriptions/constants';
import { PurchaseEvent } from 'ee/subscriptions/new/constants';
import activeStepQuery from 'ee/vue_shared/purchase_flow/graphql/queries/active_step.query.graphql';
import { s__, sprintf } from '~/locale';
import Api from 'ee/api';
import { trackTransaction } from 'ee/google_tag_manager';
import Tracking from '~/tracking';
import { addExperimentContext } from '~/tracking/utils';
import { ActiveModelError } from '~/lib/utils/error_utils';
import { isInvalidPromoCodeError } from 'ee/subscriptions/new/utils';
import { visitUrl } from '~/lib/utils/url_utility';

export default {
  components: {
    GlButton,
    GlLoadingIcon,
  },
  data() {
    return {
      idempotencyKey: uuidv4(),
      isActive: {},
      isConfirmingOrder: false,
    };
  },
  apollo: {
    isActive: {
      query: activeStepQuery,
      update: ({ activeStep }) => activeStep?.id === STEPS[3].id,
      error: (error) => this.handleError(error),
    },
  },
  computed: {
    ...mapGetters([
      'hasValidPriceDetails',
      'confirmOrderParams',
      'totalExVat',
      'vat',
      'selectedPlanDetails',
    ]),
    shouldDisableConfirmOrder() {
      return this.isConfirmingOrder || !this.hasValidPriceDetails;
    },
    orderParams() {
      return { ...this.confirmOrderParams, idempotency_key: this.idempotencyKey };
    },
    idempotencyKeyParams() {
      return [this.paymentMethodId, this.planId, this.quantity, this.selectedGroup, this.zipCode];
    },
    paymentMethodId() {
      return this.confirmOrderParams?.subscription?.payment_method_id;
    },
    planId() {
      return this.confirmOrderParams?.subscription?.plan_id;
    },
    quantity() {
      return this.confirmOrderParams?.subscription?.quantity;
    },
    selectedGroup() {
      return this.confirmOrderParams?.selected_group;
    },
    zipCode() {
      return this.confirmOrderParams?.customer?.zip_code;
    },
  },
  watch: {
    idempotencyKeyParams(newValue, oldValue) {
      if (!isEqual(newValue, oldValue)) {
        this.regenerateIdempotencyKey();
      }
    },
  },
  methods: {
    regenerateIdempotencyKey() {
      this.idempotencyKey = uuidv4();
    },
    isClientSideError(status) {
      return status >= 400 && status < 500;
    },
    handleError(error) {
      this.$emit(PurchaseEvent.ERROR, error);
    },
    trackConfirmOrder(message) {
      Tracking.event(
        'default',
        'click_button',
        addExperimentContext({ label: 'confirm_purchase', property: message }),
      );
    },
    shouldShowErrorMessageOnly(errors) {
      if (!errors?.message) {
        return false;
      }

      return isInvalidPromoCodeError(errors);
    },
    confirmOrder() {
      this.isConfirmingOrder = true;

      Api.confirmOrder(this.orderParams)
        .then(({ data }) => {
          if (data?.location) {
            const transactionDetails = {
              paymentOption: this.orderParams?.subscription?.payment_method_id,
              revenue: this.totalExVat,
              tax: this.vat,
              selectedPlan: this.selectedPlanDetails?.value,
              quantity: this.orderParams?.subscription?.quantity,
            };

            trackTransaction(transactionDetails);
            this.trackConfirmOrder(s__('Checkout|Success: subscription'));

            visitUrl(data.location);
          } else {
            let errorMessage;
            if (data?.name) {
              errorMessage = sprintf(
                s__('Checkout|Name: %{errorMessage}'),
                { errorMessage: data.name.join(', ') },
                false,
              );
            } else if (this.shouldShowErrorMessageOnly(data?.errors)) {
              errorMessage = data?.errors?.message;
            } else {
              errorMessage = data?.errors;
            }

            this.trackConfirmOrder(errorMessage);
            this.handleError(
              new ActiveModelError(data.error_attribute_map, JSON.stringify(errorMessage)),
            );
          }
        })
        .catch((error) => {
          const { status } = error?.response || {};
          // Regenerate the idempotency key on client-side errors, to ensure the server regards the new request.
          // Context: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/129830#note_1522796835.
          if (this.isClientSideError(status)) {
            this.regenerateIdempotencyKey();
          }
          this.trackConfirmOrder(error.message);
          this.handleError(error);
        })
        .finally(() => {
          this.isConfirmingOrder = false;
        });
    },
  },
  i18n: {
    confirm: s__('Checkout|Confirm purchase'),
    confirming: s__('Checkout|Confirming...'),
  },
};
</script>
<template>
  <div v-if="isActive" class="full-width gl-mt-5 gl-mb-7">
    <gl-button
      :disabled="shouldDisableConfirmOrder"
      variant="confirm"
      category="primary"
      @click="confirmOrder"
    >
      <gl-loading-icon v-if="isConfirmingOrder" inline size="sm" />
      {{ isConfirmingOrder ? $options.i18n.confirming : $options.i18n.confirm }}
    </gl-button>
  </div>
</template>
