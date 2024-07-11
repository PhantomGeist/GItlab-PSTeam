<script>
import { GlForm, GlButton, GlFormGroup, GlFormInput, GlFormSelect, GlFormText } from '@gitlab/ui';
import {
  LEADS_COMPANY_NAME_LABEL,
  LEADS_COMPANY_SIZE_LABEL,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
  companySizes,
} from 'ee/vue_shared/leads/constants';
import csrf from '~/lib/utils/csrf';
import { __ } from '~/locale';
import CountryOrRegionSelector from 'ee/trials/components/country_or_region_selector.vue';
import {
  TRIAL_COMPANY_SIZE_PROMPT,
  TRIAL_PHONE_DESCRIPTION,
  TRIAL_FORM_SUBMIT_TEXT,
  TRIAL_DESCRIPTION,
  TRIAL_REGISTRATION_DESCRIPTION,
  TRIAL_REGISTRATION_FOOTER_DESCRIPTION,
  TRIAL_REGISTRATION_FORM_SUBMIT_TEXT,
} from 'ee/trials/constants';
import { trackCompanyForm } from 'ee/google_tag_manager';

export default {
  csrf,
  components: {
    GlForm,
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlFormText,
    CountryOrRegionSelector,
  },
  inject: ['user', 'submitPath'],
  props: {
    trial: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      ...this.user,
      companyName: '',
      companySize: null,
      phoneNumber: null,
      country: '',
      state: '',
      websiteUrl: '',
    };
  },
  computed: {
    companySizeOptionsWithDefault() {
      return [
        {
          name: this.$options.i18n.companySizeSelectPrompt,
          id: null,
        },
        ...companySizes,
      ];
    },
    descriptionText() {
      return this.trial
        ? this.$options.i18n.description.trial
        : this.$options.i18n.description.registration;
    },
    submitButtonText() {
      return this.trial
        ? this.$options.i18n.formSubmitText.trial
        : this.$options.i18n.formSubmitText.registration;
    },
  },
  methods: {
    trackCompanyForm() {
      trackCompanyForm('ultimate_trial');
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    companySizeLabel: LEADS_COMPANY_SIZE_LABEL,
    companySizeSelectPrompt: TRIAL_COMPANY_SIZE_PROMPT,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    phoneNumberDescription: TRIAL_PHONE_DESCRIPTION,
    optional: __('(optional)'),
    websiteLabel: __('Website'),
    description: {
      trial: TRIAL_DESCRIPTION,
      registration: TRIAL_REGISTRATION_DESCRIPTION,
    },
    footerDescription: TRIAL_REGISTRATION_FOOTER_DESCRIPTION,
    formSubmitText: {
      trial: TRIAL_FORM_SUBMIT_TEXT,
      registration: TRIAL_REGISTRATION_FORM_SUBMIT_TEXT,
    },
  },
};
</script>

<template>
  <gl-form :action="submitPath" method="post" @submit="trackCompanyForm">
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <gl-form-text class="gl-font-base gl-text-gray-400 gl-pb-3">{{ descriptionText }}</gl-form-text>
    <div class="gl-display-flex gl-flex-direction-column gl-sm-flex-direction-row gl-mt-5">
      <gl-form-group
        :label="$options.i18n.firstNameLabel"
        label-size="sm"
        label-for="first_name"
        class="gl-mr-5 gl-w-half gl-xs-w-full"
      >
        <gl-form-input
          id="first_name"
          :value="firstName"
          name="first_name"
          data-testid="first_name"
          required
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.lastNameLabel"
        label-size="sm"
        label-for="last_name"
        class="gl-w-half gl-xs-w-full"
      >
        <gl-form-input
          id="last_name"
          :value="lastName"
          name="last_name"
          data-testid="last_name"
          required
        />
      </gl-form-group>
    </div>
    <div class="gl-display-flex gl-flex-direction-column gl-sm-flex-direction-row">
      <gl-form-group
        :label="$options.i18n.companyNameLabel"
        label-size="sm"
        label-for="company_name"
        class="gl-mr-5 gl-w-half gl-xs-w-full"
      >
        <gl-form-input
          id="company_name"
          :value="companyName"
          name="company_name"
          data-testid="company_name"
          required
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.companySizeLabel"
        label-size="sm"
        label-for="company_size"
        class="gl-w-half gl-xs-w-full"
      >
        <gl-form-select
          id="company_size"
          :value="companySize"
          name="company_size"
          :options="companySizeOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="company_size"
          required
        />
      </gl-form-group>
    </div>
    <country-or-region-selector :country="country" :state="state" data-testid="country" required />
    <gl-form-group
      :label="$options.i18n.phoneNumberLabel"
      :optional-text="$options.i18n.optional"
      label-size="sm"
      :description="$options.i18n.phoneNumberDescription"
      label-for="phone_number"
      optional
    >
      <gl-form-input
        id="phone_number"
        :value="phoneNumber"
        name="phone_number"
        type="tel"
        data-testid="phone_number"
        pattern="^(\+)*[0-9-\s]+$"
      />
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.websiteLabel"
      :optional-text="$options.i18n.optional"
      label-size="sm"
      label-for="website_url"
      optional
    >
      <gl-form-input
        id="website_url"
        :value="websiteUrl"
        name="website_url"
        data-testid="website_url"
      />
    </gl-form-group>
    <gl-button type="submit" variant="confirm">
      {{ submitButtonText }}
    </gl-button>
    <gl-form-text
      v-if="!trial"
      data-testid="footer_description_text"
      class="gl-mt-3 gl-text-gray-500"
    >
      {{ $options.i18n.footerDescription }}
    </gl-form-text>
  </gl-form>
</template>
