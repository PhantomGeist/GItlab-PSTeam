import {
  PREVENT_APPROVAL_BY_AUTHOR,
  buildSettingsList,
  mergeRequestConfiguration,
  protectedBranchesConfiguration,
  forcePushingBranchesConfiguration,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';

afterEach(() => {
  window.gon = {};
});

describe('approval_settings', () => {
  describe('buildSettingsList', () => {
    it('returns an empty object by default', () => {
      expect(buildSettingsList()).toEqual({});
    });

    it('returns the protected branches settings when the "scanResultPoliciesBlockUnprotectingBranches" feature flag is enabled', () => {
      window.gon = { features: { scanResultPoliciesBlockUnprotectingBranches: true } };
      expect(buildSettingsList()).toEqual(protectedBranchesConfiguration);
    });

    it('returns the protected branches settings when the "scanResultPoliciesBlockForcePush" feature flag is enabled', () => {
      window.gon = { features: { scanResultPoliciesBlockForcePush: true } };
      expect(buildSettingsList()).toEqual(forcePushingBranchesConfiguration);
    });

    it('returns the protected branches settings when the "scanResultPoliciesBlockUnprotectingBranches" feature flag is enabled and the "scanResultPoliciesBlockForcePush" feature flag is enabled', () => {
      window.gon = {
        features: {
          scanResultPoliciesBlockUnprotectingBranches: true,
          scanResultPoliciesBlockForcePush: true,
        },
      };
      expect(buildSettingsList()).toEqual({
        ...protectedBranchesConfiguration,
        ...forcePushingBranchesConfiguration,
      });
    });

    it('returns merge request settings for the merge request rule', () => {
      expect(buildSettingsList({ hasAnyMergeRequestRule: true })).toEqual({
        ...mergeRequestConfiguration,
      });
    });

    it('can update merge request settings', () => {
      window.gon = { features: { scanResultPoliciesBlockUnprotectingBranches: true } };
      const settings = {
        ...mergeRequestConfiguration,
        [PREVENT_APPROVAL_BY_AUTHOR]: false,
      };
      expect(buildSettingsList({ settings, hasAnyMergeRequestRule: true })).toEqual({
        ...protectedBranchesConfiguration,
        ...settings,
      });
    });

    it('has fall back values for settings', () => {
      const settings = {
        [PREVENT_APPROVAL_BY_AUTHOR]: true,
      };

      expect(buildSettingsList({ settings, hasAnyMergeRequestRule: true })).toEqual({
        ...mergeRequestConfiguration,
      });
    });
  });
});
