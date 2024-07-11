<script>
import { GlTable, GlLink, GlLabel } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    title: s__('Metrics|Metrics'),
    emptyText: s__('Metrics|No metrics to display.'),
    emptyLinkText: s__('Metrics|Check again'),
  },
  fields: [
    {
      key: 'name',
      label: s__('Metrics|Name'),
      tdAttr: { 'data-testid': 'metric-name' },
    },
    {
      key: 'description',
      label: s__('Metrics|Description'),
      tdAttr: { 'data-testid': 'metric-description' },
    },
    {
      key: 'type',
      label: s__('Metrics|Type'),
      tdAttr: { 'data-testid': 'metric-type' },
    },
  ],
  components: {
    GlTable,
    GlLink,
    GlLabel,
  },
  props: {
    metrics: {
      required: true,
      type: Array,
    },
  },
  methods: {
    labelColor(type) {
      // Colors are taken from the label's colors map: gitlab/app/helpers/labels_helper.rb
      switch (type) {
        case 'COUNTER':
          return '#6699cc'; // blue-gray
        case 'GAUGE':
          return '#cd5b45'; // dark-coral
        case 'HISTOGRAM':
          return '#009966'; // green-cyan
        case 'EXPONENTIAL HISTOGRAM': // eslint-disable-line @gitlab/require-i18n-strings
          return '#ed9121'; // carrot-orange
        default:
          return '#808080'; // gray
      }
    },
  },
};
</script>

<template>
  <div>
    <h4 class="gl-display-block gl-md-display-none! gl-my-5">{{ $options.i18n.title }}</h4>

    <gl-table
      :items="metrics"
      :fields="$options.fields"
      show-empty
      fixed
      stacked="md"
      :tbody-tr-attr="{ 'data-testid': 'metric-row' }"
    >
      <template #cell(type)="{ item }">
        <gl-label :background-color="labelColor(item.type)" :title="item.type" />
      </template>
      <!-- no date template -->
      <template #empty>
        <div class="gl-text-center">
          {{ $options.i18n.emptyText }}
          <gl-link @click="$emit('reload')">{{ $options.i18n.emptyLinkText }}</gl-link>
        </div>
      </template>
    </gl-table>
  </div>
</template>
