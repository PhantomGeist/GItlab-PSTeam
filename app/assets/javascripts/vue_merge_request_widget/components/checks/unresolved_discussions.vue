<script>
import { s__ } from '~/locale';
import notesEventHub from '~/notes/event_hub';
import ActionButtons from '../action_buttons.vue';
import MergeChecksMessage from './message.vue';

export default {
  name: 'MergeChecksUnresolvedDiscussions',
  components: {
    MergeChecksMessage,
    ActionButtons,
  },
  props: {
    check: {
      type: Object,
      required: true,
    },
  },
  computed: {
    tertiaryActionsButtons() {
      return [
        {
          text: s__('mrWidget|Go to first unresolved thread'),
          category: 'default',
          onClick: () => notesEventHub.$emit('jumpToFirstUnresolvedDiscussion'),
        },
      ];
    },
  },
};
</script>

<template>
  <merge-checks-message :check="check">
    <action-buttons v-if="check.result === 'failed'" :tertiary-buttons="tertiaryActionsButtons" />
  </merge-checks-message>
</template>
