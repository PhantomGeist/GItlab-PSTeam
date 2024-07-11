<script>
import { GlButtonGroup, GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';

export default {
  components: {
    GlButtonGroup,
    GlButton,
    GlCollapsibleListbox,
  },
  props: {
    buttons: {
      type: Array,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      selectedButtonIndex: 0,
    };
  },
  computed: {
    selectedButton() {
      return this.buttons[this.selectedButtonIndex];
    },
    items() {
      return this.buttons.map((button) => ({
        text: button.name,
        value: button.action,
        description: button.tagline,
      }));
    },
  },
  methods: {
    setButton(action) {
      this.selectedButtonIndex = this.buttons.findIndex((button) => button.action === action);
    },
    handleClick() {
      if (this.selectedButton.href) {
        visitUrl(this.selectedButton.href, true);
      } else {
        this.$emit(this.selectedButton.action);
      }
    },
  },
  i18n: {
    changeAction: __('Change action'),
  },
};
</script>

<template>
  <!--TODO: Replace button-group workaround once `split` option for new dropdowns is implemented.-->
  <!-- See issue at https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2263-->
  <gl-button-group v-if="selectedButton">
    <gl-button
      :disabled="disabled"
      variant="confirm"
      :href="selectedButton.href"
      :loading="selectedButton.loading"
      @click="handleClick"
      >{{ selectedButton.name }}</gl-button
    >
    <gl-collapsible-listbox
      class="split"
      toggle-class="gl-rounded-top-left-none! gl-rounded-bottom-left-none! gl-pl-1!"
      variant="confirm"
      text-sr-only
      :toggle-text="$options.i18n.changeAction"
      :disabled="disabled || selectedButton.loading"
      :items="items"
      :selected="selectedButton.action"
      @select="setButton"
    >
      <template #list-item="{ item }">
        <div :data-testid="`${item.value}-button`">
          <strong>{{ item.text }}</strong>
          <p class="gl-m-0">{{ item.description }}</p>
        </div>
      </template>
    </gl-collapsible-listbox>
  </gl-button-group>
</template>
