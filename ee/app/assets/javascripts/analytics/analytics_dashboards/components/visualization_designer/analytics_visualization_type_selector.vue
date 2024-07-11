<script>
import { GlDropdown, GlDropdownItem } from '@gitlab/ui';
import { s__ } from '~/locale';

const TYPES = [
  {
    value: 'LineChart',
    icon: 'chart',
    text: s__('Analytics|Line chart'),
  },
  {
    value: 'ColumnChart',
    icon: 'chart',
    text: s__('Analytics|Column chart'),
  },
  {
    value: 'DataTable',
    icon: 'table',
    text: s__('Analytics|Data table'),
  },
  {
    value: 'SingleStat',
    icon: 'table',
    text: s__('Analytics|Single statistic'),
  },
];

export default {
  name: 'AnalyticsVisualizationTypeSelector',
  components: {
    GlDropdown,
    GlDropdownItem,
  },
  props: {
    selectedVisualizationType: {
      type: String,
      required: true,
    },
  },
  computed: {
    selectedType() {
      return TYPES.find((type) => type.value === this.selectedVisualizationType);
    },
    selectedText() {
      return this.selectedType?.text || s__('Analytics|Select a visualization type');
    },
    selectedIcon() {
      return this.selectedType?.icon;
    },
  },
  methods: {
    selectVisualizationType(visualizationType) {
      this.$emit('selectVisualizationType', visualizationType);
    },
  },
  TYPES,
};
</script>

<template>
  <gl-dropdown :text="selectedText" :icon="selectedIcon" block>
    <gl-dropdown-item
      v-for="type in $options.TYPES"
      :key="type.value"
      :icon-name="type.icon"
      @click="selectVisualizationType(type.value)"
    >
      {{ type.text }}
    </gl-dropdown-item>
  </gl-dropdown>
</template>
