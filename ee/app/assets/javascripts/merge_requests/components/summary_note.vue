<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import SafeHtml from '~/vue_shared/directives/safe_html';
import UserFeedback from 'ee/ai/components/user_feedback.vue';
import SummaryNoteWrapper from './summary_note_wrapper.vue';

export default {
  name: 'SummaryNote',
  components: {
    GlLink,
    GlSprintf,
    TimeAgoTooltip,
    UserFeedback,
    SummaryNoteWrapper,
  },
  directives: {
    SafeHtml,
  },
  props: {
    summary: {
      type: Object,
      required: true,
    },
    level: {
      type: Number,
      required: false,
      default: 1,
    },
  },
  computed: {
    isReviewSummary() {
      // eslint-disable-next-line no-underscore-dangle
      return this.summary.__typename === 'MergeRequestReviewLlmSummary';
    },
    content() {
      return this.summary.contentHtml || this.summary.content;
    },
  },
};
</script>

<template>
  <div>
    <summary-note-wrapper :class="{ 'gl-bg-gray-50 gl-border-0': isReviewSummary }">
      <template #title>
        <h5 class="gl-m-0">
          <gl-sprintf v-if="isReviewSummary" :message="__('%{linkStart}%{linkEnd} review summary')">
            <template #link>
              <gl-link :href="summary.reviewer.webUrl">@{{ summary.reviewer.username }}</gl-link>
            </template>
            <template #name>
              {{ summary.reviewer.name }}
            </template>
          </gl-sprintf>
          <template v-else>{{ __('Merge request change summary') }}</template>
        </h5>
      </template>
      <template #created>
        <time-ago-tooltip
          class="gl-white-space-nowrap gl-font-sm gl-text-gray-600"
          :time="summary.createdAt"
        />
      </template>
      <template #content>
        <p v-safe-html="content" class="gl-m-0"></p>
      </template>
      <template #feedback>
        <user-feedback
          class="gl-pt-0!"
          event-name="proposed_changes_summary"
          :feedback-link-text="__('Leave feedback')"
        />
      </template>
    </summary-note-wrapper>
    <summary-note
      v-for="(review, index) in summary.children"
      :key="index"
      :summary="review"
      data-testid="nested-note"
      class="gl-ml-5"
    />
  </div>
</template>
