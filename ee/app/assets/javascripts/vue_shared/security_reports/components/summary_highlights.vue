<script>
import { GlSprintf } from '@gitlab/ui';
import { CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN } from '~/vulnerabilities/constants';
import { s__ } from '~/locale';
import { SEVERITY_CLASS_NAME_MAP } from './constants';

export default {
  components: {
    GlSprintf,
  },
  i18n: {
    highlights: s__(
      'ciReport|%{criticalStart}critical%{criticalEnd}, %{highStart}high%{highEnd} and %{otherStart}others%{otherEnd}',
    ),
  },
  props: {
    /**
     * If provided, this will display only the count for the given severity.
     */
    showSingleSeverity: {
      type: String,
      required: false,
      default: '',
      validate: (severity) =>
        !severity || [CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN].contains(severity),
    },
    highlights: {
      type: Object,
      required: true,
      validate: (highlights) =>
        [CRITICAL, HIGH].every((requiredField) => typeof highlights[requiredField] !== 'undefined'),
    },
  },
  computed: {
    criticalSeverity() {
      return this.highlights[CRITICAL];
    },
    highSeverity() {
      return this.highlights[HIGH];
    },
    otherSeverity() {
      if (typeof this.highlights.other !== 'undefined') {
        return this.highlights.other;
      }

      return Object.keys(this.highlights).reduce((total, key) => {
        return [MEDIUM, LOW, INFO, UNKNOWN].includes(key) ? total + this.highlights[key] : total;
      }, 0);
    },
  },
  cssClass: SEVERITY_CLASS_NAME_MAP,
};
</script>

<template>
  <div class="gl-font-sm">
    <strong v-if="showSingleSeverity" :class="$options.cssClass[showSingleSeverity]">{{
      highlights[showSingleSeverity]
    }}</strong>
    <gl-sprintf v-else :message="$options.i18n.highlights">
      <template #critical="{ content }"
        ><strong class="gl-text-red-800">{{ criticalSeverity }} {{ content }}</strong></template
      >
      <template #high="{ content }"
        ><strong class="gl-text-red-600">{{ highSeverity }} {{ content }}</strong></template
      >
      <template #other="{ content }"
        ><strong>{{ otherSeverity }} {{ content }}</strong></template
      >
    </gl-sprintf>
  </div>
</template>
