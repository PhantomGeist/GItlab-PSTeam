<script>
import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';

export default {
  name: 'CustomStageEventField',
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
  },
  props: {
    index: {
      type: Number,
      required: true,
    },
    eventType: {
      type: String,
      required: true,
    },
    eventsList: {
      type: Array,
      required: true,
    },
    fieldLabel: {
      type: String,
      required: true,
    },
    defaultDropdownText: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasIdentifierError: {
      type: Boolean,
      required: false,
      default: false,
    },
    identifierError: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return { selectedValue: null };
  },
  computed: {
    fieldName() {
      const { eventType, index } = this;
      return `custom-stage-${eventType}-${index}`;
    },
    selectedEvent() {
      return this.eventsList.find(({ value }) => value === this.selectedValue);
    },
    toggleText() {
      return this.selectedEvent?.text || this.defaultDropdownText;
    },
  },
  methods: {
    itemSelected(value) {
      this.selectedValue = value;
      this.$emit('update-identifier', value);
    },
  },
};
</script>
<template>
  <gl-form-group
    class="gl-w-half gl-mr-2"
    :data-testid="fieldName"
    :label="fieldLabel"
    :state="hasIdentifierError"
    :invalid-feedback="identifierError"
  >
    <gl-collapsible-listbox
      :items="eventsList"
      :selected="selectedValue"
      :disabled="disabled"
      :toggle-text="toggleText"
      block
      @select="itemSelected"
    />
  </gl-form-group>
</template>
