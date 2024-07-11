<script>
import { GlTab, GlTabs, GlButton, GlTooltipDirective } from '@gitlab/ui';

import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

import Tracking from '~/tracking';
import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
} from '../constants';
import MergeCommitsExportButton from './violations_report/shared/merge_commits_export_button.vue';
import ReportHeader from './shared/report_header.vue';

export default {
  name: 'ComplianceReportsApp',
  components: {
    GlTabs,
    GlTab,
    GlButton,
    MergeCommitsExportButton,
    ReportHeader,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [Tracking.mixin()],
  inject: ['adherenceReportUiEnabled', 'complianceFrameworkReportUiEnabled'],
  props: {
    mergeCommitsCsvExportPath: {
      type: String,
      required: false,
      default: '',
    },
    frameworksCsvExportPath: {
      type: String,
      required: false,
      default: '',
    },
    violationsCsvExportPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    isViolationsReport() {
      return this.$route.name === ROUTE_VIOLATIONS;
    },
    isProjectsReport() {
      return this.$route.name === ROUTE_PROJECTS;
    },
    showMergeCommitsExportButton() {
      return Boolean(this.mergeCommitsCsvExportPath) && this.isViolationsReport;
    },
    showViolationsExportButton() {
      return Boolean(this.violationsCsvExportPath) && this.isViolationsReport;
    },
    showProjectsExportButton() {
      return Boolean(this.frameworksCsvExportPath) && this.isProjectsReport;
    },
    tabIndex() {
      const adherenceTab = this.adherenceReportUiEnabled ? [ROUTE_STANDARDS_ADHERENCE] : [];

      const currentTabs = [...adherenceTab, ROUTE_VIOLATIONS, ROUTE_FRAMEWORKS, ROUTE_PROJECTS];

      return currentTabs.indexOf(this.$route.name);
    },
    standardsAdherenceTabLinkAttributes() {
      return { 'data-testid': 'standards-adherence-tab' };
    },
    violationsTabLinkAttributes() {
      return { 'data-testid': 'violations-tab' };
    },
    frameworksTabLinkAttributes() {
      return { 'data-testid': 'frameworks-tab' };
    },
    projectsTabLinkAttributes() {
      return { 'data-testid': 'projects-tab' };
    },
  },
  methods: {
    goTo(name) {
      if (this.$route.name !== name) {
        this.$router.push({ name });
        this.track('click_report_tab', { label: name });
      }
    },
  },
  ROUTE_STANDARDS: ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  i18n: {
    export: s__('Compliance Center|Export full report as CSV'),
    exportTitle: {
      projects: s__(
        'Compliance Center|Export projects as CSV. You will be emailed after the export is processed.',
      ),
      violations: s__(
        'Compliance Center|Export merge request violations as CSV. You will be emailed after the export is processed.',
      ),
    },
    frameworksTab: s__('Compliance Center|Frameworks'),
    projectsTab: __('Projects'),
    heading: __('Compliance center'),
    standardsAdherenceTab: s__('Compliance Center|Standards Adherence'),
    subheading: __(
      'Report and manage standards adherence, violations, and compliance frameworks for the group.',
    ),
    violationsTab: s__('Compliance Center|Violations'),
  },
  documentationPath: helpPagePath('user/compliance/compliance_center/index.md'),
};
</script>
<template>
  <div>
    <report-header
      :heading="$options.i18n.heading"
      :subheading="$options.i18n.subheading"
      :documentation-path="$options.documentationPath"
    >
      <template #actions>
        <div align="right">
          <merge-commits-export-button
            v-if="showMergeCommitsExportButton"
            :merge-commits-csv-export-path="mergeCommitsCsvExportPath"
          />
          <gl-button
            v-if="showViolationsExportButton"
            v-gl-tooltip.hover
            :title="$options.i18n.exportTitle.violations"
            :aria-label="$options.i18n.export"
            icon="export"
            data-testid="violations-export"
            data-track-action="click_export"
            data-track-label="export_all_violations"
            class="gl-mt-3"
            :href="violationsCsvExportPath"
          >
            {{ $options.i18n.export }}
          </gl-button>
          <gl-button
            v-if="showProjectsExportButton"
            v-gl-tooltip.hover
            :title="$options.i18n.exportTitle.projects"
            :aria-label="$options.i18n.export"
            icon="export"
            data-testid="projects-export"
            data-track-action="click_export"
            data-track-label="export_all_frameworks"
            :href="frameworksCsvExportPath"
          >
            {{ $options.i18n.export }}
          </gl-button>
        </div>
      </template>
    </report-header>

    <gl-tabs :value="tabIndex" content-class="gl-p-0" lazy>
      <gl-tab
        v-if="adherenceReportUiEnabled"
        :title="$options.i18n.standardsAdherenceTab"
        :title-link-attributes="standardsAdherenceTabLinkAttributes"
        data-testid="standards-adherence-tab-content"
        @click="goTo($options.ROUTE_STANDARDS)"
      />
      <gl-tab
        :title="$options.i18n.violationsTab"
        :title-link-attributes="violationsTabLinkAttributes"
        data-testid="violations-tab-content"
        @click="goTo($options.ROUTE_VIOLATIONS)"
      />
      <gl-tab
        v-if="complianceFrameworkReportUiEnabled"
        :title="$options.i18n.frameworksTab"
        :title-link-attributes="frameworksTabLinkAttributes"
        data-testid="frameworks-tab-content"
        @click="goTo($options.ROUTE_FRAMEWORKS)"
      />
      <gl-tab
        :title="$options.i18n.projectsTab"
        :title-link-attributes="projectsTabLinkAttributes"
        data-testid="projects-tab-content"
        @click="goTo($options.ROUTE_PROJECTS)"
      />
    </gl-tabs>
    <router-view />
  </div>
</template>
