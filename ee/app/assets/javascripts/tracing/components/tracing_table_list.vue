<script>
import { GlTable, GlLink, GlTruncate } from '@gitlab/ui';
import { s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { formatTraceDuration } from './trace_utils';

export const tableDataClass = 'gl-display-flex gl-md-display-table-cell gl-align-items-center';
export default {
  name: 'TracingTableList',
  i18n: {
    title: s__('Tracing|Traces'),
    emptyText: s__('Tracing|No traces to display.'),
    emptyLinkText: s__('Tracing|Check again'),
  },
  fields: [
    {
      key: 'timestamp',
      label: s__('Tracing|Date'),
      tdClass: tableDataClass,
    },
    {
      key: 'service_name',
      label: s__('Tracing|Service'),
      tdClass: tableDataClass,
    },
    {
      key: 'operation',
      label: s__('Tracing|Operation'),
      tdClass: tableDataClass,
    },
    {
      key: 'duration',
      label: s__('Tracing|Duration'),
      thClass: 'gl-w-15p',
      tdClass: tableDataClass,
    },
  ],
  components: {
    GlTable,
    GlLink,
    GlTruncate,
  },
  props: {
    traces: {
      required: true,
      type: Array,
    },
    highlightedTraceId: {
      required: false,
      type: String,
      default: () => null,
    },
  },
  computed: {
    formattedTraces() {
      return this.traces.map((x) => ({
        ...x,
        timestamp: formatDate(x.timestamp),
        duration: formatTraceDuration(x.duration_nano),
      }));
    },
  },
  methods: {
    onRowClicked(item, _index, event) {
      this.$emit('trace-clicked', { traceId: item.trace_id, clickEvent: event });
    },
    rowClass(item, type) {
      if (!item || type !== 'row') return '';
      if (item.trace_id === this.highlightedTraceId) return 'gl-bg-t-gray-a-08';
      return '';
    },
  },
};
</script>

<template>
  <div>
    <h4 class="gl-display-block gl-md-display-none! gl-my-5">{{ $options.i18n.title }}</h4>

    <gl-table
      :items="formattedTraces"
      :fields="$options.fields"
      show-empty
      fixed
      stacked="md"
      :tbody-tr-class="rowClass"
      selectable
      select-mode="single"
      selected-variant=""
      @row-clicked="onRowClicked"
    >
      <template #cell(service_name)="{ item }">
        <gl-truncate :text="item.service_name" with-tooltip />
      </template>

      <template #cell(operation)="{ item }">
        <gl-truncate :text="item.operation" with-tooltip />
      </template>

      <template #empty>
        <div class="gl-text-center">
          {{ $options.i18n.emptyText }}
          <gl-link @click="$emit('reload')">{{ $options.i18n.emptyLinkText }}</gl-link>
        </div>
      </template>
    </gl-table>
  </div>
</template>
