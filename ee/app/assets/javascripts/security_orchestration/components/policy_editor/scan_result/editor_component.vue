<script>
import Vue from 'vue';
import { isEmpty } from 'lodash';
import { GlAlert, GlEmptyState, GlButton } from '@gitlab/ui';
import { joinPaths, visitUrl, setUrlFragment } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  ADD_ACTION_LABEL,
  BRANCHES_KEY,
  EDITOR_MODE_YAML,
  EDITOR_MODE_RULE,
  SECURITY_POLICY_ACTIONS,
  GRAPHQL_ERROR_MESSAGE,
  PARSING_ERROR_MESSAGE,
  ACTIONS_LABEL,
  ADD_RULE_LABEL,
  RULES_LABEL,
  MAX_ALLOWED_RULES_LENGTH,
} from '../constants';
import EditorLayout from '../editor_layout.vue';
import { assignSecurityPolicyProject, modifyPolicy } from '../utils';
import DimDisableContainer from '../dim_disable_container.vue';
import SettingsSection from './settings/settings_section.vue';
import PolicyActionBuilder from './action/action_section.vue';
import PolicyRuleBuilder from './rule/rule_section.vue';

import {
  ANY_MERGE_REQUEST,
  BLOCK_UNPROTECTING_BRANCHES,
  PREVENT_FORCE_PUSHING,
  buildSettingsList,
  createPolicyObject,
  DEFAULT_SCAN_RESULT_POLICY,
  getInvalidBranches,
  fromYaml,
  toYaml,
  approversOutOfSync,
  emptyBuildRule,
  invalidScanners,
  invalidSeverities,
  invalidVulnerabilitiesAllowed,
  invalidVulnerabilityStates,
  invalidVulnerabilityAge,
  invalidVulnerabilityAttributes,
  humanizeInvalidBranchesError,
  invalidBranchType,
} from './lib';

export default {
  ADD_RULE_LABEL,
  RULES_LABEL,
  SECURITY_POLICY_ACTIONS,
  EDITOR_MODE_YAML,
  EDITOR_MODE_RULE,
  i18n: {
    ADD_ACTION_LABEL,
    PARSING_ERROR_MESSAGE,
    createMergeRequest: __('Configure with a merge request'),
    notOwnerButtonText: __('Learn more'),
    notOwnerDescription: s__(
      'SecurityOrchestration|Scan result policies can only be created by project owners.',
    ),
    settingsTitle: s__('ScanResultPolicy|Override project approval settings'),
    yamlPreview: s__('SecurityOrchestration|.yaml preview'),
    ACTIONS_LABEL,
    settingWarningTitle: s__('SecurityOrchestration|Only overriding settings will take effect'),
    settingWarningDescription: s__(
      "SecurityOrchestration|For any MR that matches this policy's rules, only the override project approval settings apply. No additional approvals are required.",
    ),
    settingErrorTitle: s__('SecurityOrchestration|Cannot create an empty policy'),
    settingErrorDescription: s__(
      "SecurityOrchestration|This policy doesn't contain any actions or override project approval settings. You cannot create an empty policy.",
    ),
  },
  components: {
    DimDisableContainer,
    GlAlert,
    GlButton,
    GlEmptyState,
    PolicyActionBuilder,
    EditorLayout,
    PolicyRuleBuilder,
    SettingsSection,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'disableScanPolicyUpdate',
    'policyEditorEmptyStateSvgPath',
    'namespaceId',
    'namespacePath',
    'scanPolicyDocumentationPath',
    'scanResultPolicyApprovers',
    'namespaceType',
  ],
  props: {
    assignedPolicyProject: {
      type: Object,
      required: true,
    },
    existingPolicy: {
      type: Object,
      required: false,
      default: null,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    const defaultPolicyObject = fromYaml({ manifest: DEFAULT_SCAN_RESULT_POLICY });

    if (
      this.glFeatures.scanResultPoliciesBlockUnprotectingBranches ||
      this.glFeatures.scanResultPoliciesBlockForcePush
    ) {
      defaultPolicyObject.approval_settings = {};

      if (this.glFeatures.scanResultPoliciesBlockUnprotectingBranches) {
        defaultPolicyObject.approval_settings[BLOCK_UNPROTECTING_BRANCHES] = true;
      }

      if (this.glFeatures.scanResultPoliciesBlockForcePush) {
        defaultPolicyObject.approval_settings[PREVENT_FORCE_PUSHING] = true;
      }
    }

    const yamlEditorValue = toYaml(this.existingPolicy || defaultPolicyObject);

    const { policy, hasParsingError } = createPolicyObject(yamlEditorValue);

    return {
      errors: { action: [] },
      invalidBranches: [],
      isCreatingMR: false,
      isRemovingPolicy: false,
      newlyCreatedPolicyProject: null,
      policy,
      hasParsingError,
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'scan-result-policy-editor',
      ),
      mode: EDITOR_MODE_RULE,
      existingApprovers: this.scanResultPolicyApprovers,
      yamlEditorValue,
    };
  },
  computed: {
    disableUpdate() {
      return !this.hasParsingError && this.hasEmptyActions && this.hasEmptySettings;
    },
    settings() {
      return buildSettingsList({
        settings: this.policy.approval_settings,
        hasAnyMergeRequestRule: this.hasMergeRequestRule,
      });
    },
    originalName() {
      return this.existingPolicy?.name;
    },
    policyActionName() {
      return this.isEditing
        ? this.$options.SECURITY_POLICY_ACTIONS.REPLACE
        : this.$options.SECURITY_POLICY_ACTIONS.APPEND;
    },
    isWithinLimit() {
      return this.policy.rules?.length < MAX_ALLOWED_RULES_LENGTH;
    },
    hasEmptyActions() {
      return !this.policy.actions?.length;
    },
    hasEmptyRules() {
      return this.policy.rules?.length === 0 || this.policy.rules?.at(0)?.type === '';
    },
    hasEmptySettings() {
      return (
        isEmpty(this.policy.approval_settings) ||
        Object.values(this.policy.approval_settings).every((value) => {
          if (typeof value === 'boolean') {
            return !value;
          }
          return true;
        })
      );
    },
    hasMergeRequestRule() {
      return this.policy.rules?.some(({ type }) => type === ANY_MERGE_REQUEST);
    },
    isActiveRuleMode() {
      return this.mode === EDITOR_MODE_RULE && !this.hasParsingError;
    },
    allBranches() {
      return this.policy.rules.flatMap((rule) => rule.branches);
    },
    rulesHaveBranches() {
      return this.policy.rules.some(this.ruleHasBranchesProperty);
    },
    shouldShowSettings() {
      return (
        this.glFeatures.scanResultPoliciesBlockUnprotectingBranches ||
        this.glFeatures.scanResultAnyMergeRequest ||
        this.glFeatures.scanResultPoliciesBlockForcePush
      );
    },
    settingAlert() {
      if (this.hasEmptySettings) {
        return {
          variant: 'danger',
          title: this.$options.i18n.settingErrorTitle,
          description: this.$options.i18n.settingErrorDescription,
        };
      }
      return {
        variant: 'warning',
        title: this.$options.i18n.settingWarningTitle,
        description: this.$options.i18n.settingWarningDescription,
      };
    },
  },
  watch: {
    invalidBranches(branches) {
      if (branches.length > 0) {
        this.handleError(new Error(humanizeInvalidBranchesError([...branches])));
      } else {
        this.$emit('error', '');
      }
    },
  },
  methods: {
    ruleHasBranchesProperty(rule) {
      return BRANCHES_KEY in rule;
    },
    addAction() {
      this.$set(this.policy, 'actions', [{ type: 'require_approval', approvals_required: 1 }]);
      this.updateYamlEditorValue(this.policy);
    },
    removeAction() {
      const { actions, ...newPolicy } = this.policy;
      this.policy = newPolicy;
      this.updateYamlEditorValue(this.policy);
      this.updatePolicyApprovers({});
    },
    updateAction(actionIndex, values) {
      this.policy.actions.splice(actionIndex, 1, values);
      this.$set(this.errors, 'action', []);
      this.updateYamlEditorValue(this.policy);
    },
    updateSettings(values) {
      if (!this.policy.approval_settings) {
        Vue.set(this.policy, 'approval_settings', values);
      } else {
        this.policy.approval_settings = values;
      }

      this.updateYamlEditorValue(this.policy);
    },
    addRule() {
      this.policy.rules.push(emptyBuildRule());
      this.updateYamlEditorValue(this.policy);
    },
    removeRule(ruleIndex) {
      this.policy.rules.splice(ruleIndex, 1);
      this.updateYamlEditorValue(this.policy);
    },
    updateRule(ruleIndex, rule) {
      this.policy.rules.splice(ruleIndex, 1, rule);
      if (
        this.glFeatures.scanResultPoliciesBlockUnprotectingBranches ||
        this.glFeatures.scanResultAnyMergeRequest ||
        this.glFeatures.scanResultPoliciesBlockForcePush
      ) {
        this.updateSettings(this.settings);
      }
      this.updateYamlEditorValue(this.policy);
    },
    handleError(error) {
      if (this.isActiveRuleMode && error.cause?.length) {
        const updatedErrors = error.cause.reduce(
          (acc, cause) => {
            switch (cause.field) {
              case 'approver_ids':
              default:
                acc.action.push(cause);
            }
            return acc;
          },
          { action: [] },
        );
        this.errors = updatedErrors;
      } else if (error.message.toLowerCase().includes('graphql')) {
        this.$emit('error', GRAPHQL_ERROR_MESSAGE);
      } else {
        this.$emit('error', error.message);
      }
    },
    handleParsingError() {
      this.hasParsingError = true;
    },
    async getSecurityPolicyProject() {
      if (!this.newlyCreatedPolicyProject && !this.assignedPolicyProject.fullPath) {
        this.newlyCreatedPolicyProject = await assignSecurityPolicyProject(this.namespacePath);
      }

      return this.newlyCreatedPolicyProject || this.assignedPolicyProject;
    },
    async handleModifyPolicy(act) {
      const action = act || this.policyActionName;

      this.$emit('error', '');
      this.setLoadingFlag(action, true);

      try {
        const assignedPolicyProject = await this.getSecurityPolicyProject();
        const mergeRequest = await modifyPolicy({
          action,
          assignedPolicyProject,
          name: this.originalName || fromYaml({ manifest: this.yamlEditorValue })?.name,
          namespacePath: this.namespacePath,
          yamlEditorValue: this.yamlEditorValue,
        });

        this.redirectToMergeRequest({ mergeRequest, assignedPolicyProject });
      } catch (e) {
        this.handleError(e);
        this.setLoadingFlag(action, false);
      }
    },
    setLoadingFlag(action, val) {
      if (action === SECURITY_POLICY_ACTIONS.REMOVE) {
        this.isRemovingPolicy = val;
      } else {
        this.isCreatingMR = val;
      }
    },
    handleSetPolicyProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    redirectToMergeRequest({ mergeRequest, assignedPolicyProject }) {
      visitUrl(
        joinPaths(
          gon.relative_url_root || '/',
          assignedPolicyProject.fullPath,
          '/-/merge_requests',
          mergeRequest.id,
        ),
      );
    },
    updateYaml(manifest) {
      const { policy, hasParsingError } = createPolicyObject(manifest);

      this.yamlEditorValue = manifest;
      this.hasParsingError = hasParsingError;
      this.policy = policy;
    },
    updateYamlEditorValue(policy) {
      this.yamlEditorValue = toYaml(policy);
    },
    async changeEditorMode(mode) {
      this.mode = mode;
      if (this.isActiveRuleMode) {
        this.hasParsingError = this.invalidForRuleMode();

        if (
          !this.hasEmptyRules &&
          this.namespaceType === NAMESPACE_TYPES.PROJECT &&
          this.rulesHaveBranches
        ) {
          this.invalidBranches = await getInvalidBranches({
            branches: this.allBranches,
            projectId: this.namespaceId,
          });
        }
      }
    },
    updatePolicyApprovers(values) {
      this.existingApprovers = values;
    },
    invalidForRuleMode() {
      const invalidApprovers = approversOutOfSync(this.policy.actions?.[0], this.existingApprovers);
      const { rules } = this.policy;

      return (
        invalidApprovers ||
        invalidScanners(rules) ||
        invalidSeverities(rules) ||
        invalidVulnerabilitiesAllowed(rules) ||
        invalidVulnerabilityStates(rules) ||
        invalidBranchType(rules) ||
        invalidVulnerabilityAge(rules) ||
        invalidVulnerabilityAttributes(rules)
      );
    },
  },
};
</script>

<template>
  <editor-layout
    v-if="!disableScanPolicyUpdate"
    :custom-save-button-text="$options.i18n.createMergeRequest"
    :disable-update="disableUpdate"
    :has-parsing-error="hasParsingError"
    :is-editing="isEditing"
    :is-removing-policy="isRemovingPolicy"
    :is-updating-policy="isCreatingMR"
    :parsing-error="$options.i18n.PARSING_ERROR_MESSAGE"
    :policy="policy"
    :yaml-editor-value="yamlEditorValue"
    @remove-policy="handleModifyPolicy($options.SECURITY_POLICY_ACTIONS.REMOVE)"
    @save-policy="handleModifyPolicy()"
    @set-policy-property="handleSetPolicyProperty"
    @update-yaml="updateYaml"
    @update-editor-mode="changeEditorMode"
  >
    <template #rules>
      <dim-disable-container :disabled="hasParsingError">
        <template #title>
          <h4>{{ $options.RULES_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-bg-gray-10 gl-rounded-base gl-p-6"></div>
        </template>

        <policy-rule-builder
          v-for="(rule, index) in policy.rules"
          :key="index"
          class="gl-mb-4"
          :init-rule="rule"
          @changed="updateRule(index, $event)"
          @remove="removeRule(index)"
        />

        <div
          v-if="isWithinLimit"
          class="security-policies-bg-gray-10 gl-rounded-base gl-p-5 gl-mb-5"
        >
          <gl-button variant="link" data-testid="add-rule" icon="plus" @click="addRule">
            {{ $options.ADD_RULE_LABEL }}
          </gl-button>
        </div>
      </dim-disable-container>
    </template>
    <template #actions>
      <dim-disable-container :disabled="hasParsingError">
        <template #title>
          <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
        </template>

        <template #disabled>
          <div class="gl-bg-gray-10 gl-rounded-base gl-p-6"></div>
        </template>

        <div v-if="Boolean(policy.actions)">
          <policy-action-builder
            v-for="(action, index) in policy.actions"
            :key="index"
            class="gl-mb-4"
            :init-action="action"
            :errors="errors.action"
            :existing-approvers="existingApprovers"
            @error="handleParsingError"
            @updateApprovers="updatePolicyApprovers"
            @changed="updateAction(index, $event)"
            @remove="removeAction"
          />
        </div>

        <div v-else class="gl-bg-gray-10 gl-rounded-base gl-p-5 gl-mb-5">
          <gl-button variant="link" data-testid="add-action" icon="plus" @click="addAction">
            {{ $options.i18n.ADD_ACTION_LABEL }}
          </gl-button>
        </div>
      </dim-disable-container>
    </template>
    <template #settings>
      <dim-disable-container v-if="shouldShowSettings" :disabled="hasParsingError">
        <template #title>
          <h4>{{ $options.i18n.settingsTitle }}</h4>
        </template>

        <template #disabled>
          <div class="gl-bg-gray-10 gl-rounded-base gl-p-6"></div>
        </template>

        <settings-section :rules="policy.rules" :settings="settings" @changed="updateSettings" />
      </dim-disable-container>
      <gl-alert
        v-if="!hasParsingError && hasEmptyActions"
        data-testid="empty-actions-alert"
        class="gl-mb-5"
        :title="settingAlert.title"
        :variant="settingAlert.variant"
        :dismissible="false"
      >
        {{ settingAlert.description }}
      </gl-alert>
    </template>
  </editor-layout>
  <gl-empty-state
    v-else
    :description="$options.i18n.notOwnerDescription"
    :primary-button-link="documentationPath"
    :primary-button-text="$options.i18n.notOwnerButtonText"
    :svg-path="policyEditorEmptyStateSvgPath"
    :svg-height="null"
    title=""
  />
</template>
