import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const BLOCK_UNPROTECTING_BRANCHES = 'block_unprotecting_branches';
export const PREVENT_FORCE_PUSHING = 'prevent_force_pushing';
export const PREVENT_APPROVAL_BY_AUTHOR = 'prevent_approval_by_author';
export const PREVENT_APPROVAL_BY_COMMIT_AUTHOR = 'prevent_approval_by_commit_author';
export const REMOVE_APPROVALS_WITH_NEW_COMMIT = 'remove_approvals_with_new_commit';
export const REQUIRE_PASSWORD_TO_APPROVE = 'require_password_to_approve';

export const protectedBranchesConfiguration = {
  [BLOCK_UNPROTECTING_BRANCHES]: false,
};

export const forcePushingBranchesConfiguration = {
  [PREVENT_FORCE_PUSHING]: false,
};

export const PROTECTED_BRANCHES_CONFIGURATION_KEYS = [
  BLOCK_UNPROTECTING_BRANCHES,
  PREVENT_FORCE_PUSHING,
];

export const MERGE_REQUEST_CONFIGURATION_KEYS = [
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
  REQUIRE_PASSWORD_TO_APPROVE,
];

export const mergeRequestConfiguration = {
  [PREVENT_APPROVAL_BY_AUTHOR]: true,
  [PREVENT_APPROVAL_BY_COMMIT_AUTHOR]: true,
  [REMOVE_APPROVALS_WITH_NEW_COMMIT]: true,
  [REQUIRE_PASSWORD_TO_APPROVE]: true,
};

export const SETTINGS_HUMANIZED_STRINGS = {
  [BLOCK_UNPROTECTING_BRANCHES]: s__('ScanResultPolicy|Prevent branch protection modification'),
  [PREVENT_FORCE_PUSHING]: s__('ScanResultPolicy|Prevent pushing and force pushing'),
  [PREVENT_APPROVAL_BY_AUTHOR]: s__("ScanResultPolicy|Prevent approval by merge request's author"),
  [PREVENT_APPROVAL_BY_COMMIT_AUTHOR]: s__('ScanResultPolicy|Prevent approval by commit author'),
  [REMOVE_APPROVALS_WITH_NEW_COMMIT]: s__('ScanResultPolicy|Remove all approvals with new commit'),
  [REQUIRE_PASSWORD_TO_APPROVE]: s__("ScanResultPolicy|Require the user's password to approve"),
};

export const SETTINGS_TOOLTIP = {
  [PREVENT_APPROVAL_BY_AUTHOR]: s__(
    'ScanResultPolicy|When enabled, two person approval will be required on all MRs as merge request authors cannot approve their own MRs and merge them unilaterally',
  ),
};

export const SETTINGS_POPOVER_STRINGS = {
  [BLOCK_UNPROTECTING_BRANCHES]: {
    title: s__('ScanResultPolicy|Recommended setting'),
    description: s__(
      'ScanResultPolicy|You have selected any protected branch option as a condition. To better protect your project, it is recommended to enable the protect branch settings. %{linkStart}Learn more.%{linkEnd}',
    ),
    featureName: 'security_policy_protected_branch_modification',
  },
};

export const SETTINGS_LINKS = {
  [BLOCK_UNPROTECTING_BRANCHES]: helpPagePath(
    '/user/application_security/policies/scan-result-policies.html',
  ),
};

export const VALID_APPROVAL_SETTINGS = [
  ...PROTECTED_BRANCHES_CONFIGURATION_KEYS,
  ...MERGE_REQUEST_CONFIGURATION_KEYS,
];

export const PERMITTED_INVALID_SETTINGS_KEY = 'block_protected_branch_modification';

export const PERMITTED_INVALID_SETTINGS = {
  [PERMITTED_INVALID_SETTINGS_KEY]: {
    enabled: true,
  },
};

/**
 * Build settings based on provided flags, scalable for more flags in future
 * @param hasAnyMergeRequestRule
 * @returns {Object} final settings
 */
const buildConfig = ({ hasAnyMergeRequestRule } = { hasAnyMergeRequestRule: false }) => {
  let configuration = {};

  const extendConfiguration = (predicate, extension) => {
    if (predicate) {
      configuration = {
        ...configuration,
        ...extension,
      };
    }
  };

  extendConfiguration(
    gon.features?.scanResultPoliciesBlockUnprotectingBranches,
    protectedBranchesConfiguration,
  );
  extendConfiguration(
    gon.features?.scanResultPoliciesBlockForcePush,
    forcePushingBranchesConfiguration,
  );
  extendConfiguration(hasAnyMergeRequestRule, mergeRequestConfiguration);

  return configuration;
};

/**
 * Map dynamic approval settings to defined list and update only enable property
 * @param settings
 * @param hasAnyMergeRequestRule
 * @returns {Object}
 */
export const buildSettingsList = (
  { settings, hasAnyMergeRequestRule } = {
    settings: {},
    hasAnyMergeRequestRule: false,
  },
) => {
  const configuration = buildConfig({ hasAnyMergeRequestRule });

  return Object.keys(configuration).reduce((acc, setting) => {
    const hasEnabledProperty = settings ? setting in settings : false;
    const enabled = hasEnabledProperty ? settings[setting] : configuration[setting];

    acc[setting] = enabled;

    return acc;
  }, {});
};
