<script>
import { GlAccordion, GlTooltipDirective } from '@gitlab/ui';
import { isEmpty } from 'lodash';
import { s__ } from '~/locale';
import { getBaseURL, joinPaths } from '~/lib/utils/url_utility';
import {
  MERGE_REQUEST_CONFIGURATION_KEYS,
  BLOCK_UNPROTECTING_BRANCHES,
  PREVENT_FORCE_PUSHING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import SettingsItem from './settings_item.vue';

export default {
  i18n: {
    emptyMessage: s__('ScanResultPolicy|No settings available for this policy'),
    protectedBranchTitle: s__('ScanResultPolicy|Protected branch settings'),
    mergeRequestTitle: s__('ScanResultPolicy|Merge request approval settings'),
    protectedBranchesDescription: s__(
      'ScanResultPolicy|If selected, the following choices will overwrite %{linkStart}project settings%{linkEnd} but only affect the branches selected in the policy.',
    ),
    mergeRequestDescription: s__(
      'ScanResultPolicy|If selected, the following choices will overwrite %{linkStart}project settings%{linkEnd} for approval rules created by this policy.',
    ),
  },
  components: {
    GlAccordion,
    SettingsItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['namespacePath'],
  props: {
    rules: {
      type: Array,
      required: false,
      default: () => [],
    },
    settings: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    protectedBranchSettings() {
      const settings = [];

      if (this.glFeatures.scanResultPoliciesBlockUnprotectingBranches) {
        settings.push(BLOCK_UNPROTECTING_BRANCHES);
      }

      if (this.glFeatures.scanResultPoliciesBlockForcePush) {
        settings.push(PREVENT_FORCE_PUSHING);
      }

      return this.groupSettingsBy(settings);
    },
    mergeRequestSettings() {
      return this.groupSettingsBy(MERGE_REQUEST_CONFIGURATION_KEYS);
    },
    protectedBranchesSettingLink() {
      return joinPaths(getBaseURL(), this.namespacePath, '-', 'settings/repository');
    },
    mergeRequestSettingLink() {
      return joinPaths(getBaseURL(), this.namespacePath, '-', 'settings/merge_requests');
    },
  },
  methods: {
    updateSetting({ key, value }) {
      const updates = { [key]: value };
      this.updatePolicy(updates);
    },
    updatePolicy(updates = {}) {
      this.$emit('changed', { ...this.settings, ...updates });
    },
    groupSettingsBy(groupNameKeys) {
      return Object.entries(this.settings).reduce((acc, [key, setting]) => {
        if (groupNameKeys.includes(key)) {
          acc[key] = setting;
        }

        return acc;
      }, {});
    },
    isSettingsEmpty(settings) {
      return isEmpty(settings);
    },
  },
};
</script>

<template>
  <div class="gl-mb-3">
    <gl-accordion :header-level="3">
      <div
        v-if="isSettingsEmpty(protectedBranchSettings) && isSettingsEmpty(mergeRequestSettings)"
        data-testid="empty-state"
      >
        {{ $options.i18n.emptyMessage }}
      </div>
      <settings-item
        v-if="!isSettingsEmpty(protectedBranchSettings)"
        data-testid="protected-branches-setting"
        :description="$options.i18n.protectedBranchesDescription"
        :link="protectedBranchesSettingLink"
        :title="$options.i18n.protectedBranchTitle"
        :rules="rules"
        :settings="protectedBranchSettings"
        @update="updateSetting"
      />
      <settings-item
        v-if="!isSettingsEmpty(mergeRequestSettings)"
        data-testid="merge-request-setting"
        :description="$options.i18n.mergeRequestDescription"
        :link="mergeRequestSettingLink"
        :title="$options.i18n.mergeRequestTitle"
        :settings="mergeRequestSettings"
        @update="updateSetting"
      />
    </gl-accordion>
  </div>
</template>
