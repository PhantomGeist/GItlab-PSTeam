<script>
import { GlBadge, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  UPGRADE_STATUS_AVAILABLE,
  UPGRADE_STATUS_RECOMMENDED,
  I18N_UPGRADE_STATUS_AVAILABLE,
  I18N_UPGRADE_STATUS_RECOMMENDED,
  I18N_UPGRADE_STATUS_AVAILABLE_TOOLTIP,
  I18N_UPGRADE_STATUS_RECOMMENDED_TOOLTIP,
  RUNNER_INSTALL_HELP_PATH,
  RUNNER_VERSION_HELP_PATH,
} from '../constants';

export default {
  name: 'RunnerUpgradeStatusBadge',
  components: {
    GlBadge,
    GlLink,
    GlPopover,
    GlSprintf,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    runner: {
      required: true,
      type: Object,
    },
    size: {
      type: String,
      default: null,
      required: false,
    },
  },
  computed: {
    shouldShowUpgradeStatus() {
      return (
        this.glFeatures?.runnerUpgradeManagement ||
        this.glFeatures?.runnerUpgradeManagementForNamespace
      );
    },
    upgradeStatus() {
      return this.runner.upgradeStatus;
    },
    badge() {
      if (!this.shouldShowUpgradeStatus) {
        return null;
      }

      switch (this.upgradeStatus) {
        case UPGRADE_STATUS_AVAILABLE:
          return {
            variant: 'info',
            label: I18N_UPGRADE_STATUS_AVAILABLE,
            tooltip: I18N_UPGRADE_STATUS_AVAILABLE_TOOLTIP,
            popover: s__(
              'Runners|%{installLinkStart}Upgrade GitLab Runner%{installLinkEnd} to match your GitLab version. %{versionLinkStart}Major and minor versions%{versionLinkEnd} must match.',
            ),
          };
        case UPGRADE_STATUS_RECOMMENDED:
          return {
            variant: 'warning',
            label: I18N_UPGRADE_STATUS_RECOMMENDED,
            tooltip: I18N_UPGRADE_STATUS_RECOMMENDED_TOOLTIP,
            popover: s__(
              'Runners|%{installLinkStart}Upgrade GitLab Runner%{installLinkEnd} to match your GitLab version. This upgrade is highly recommended for this runner and may contain security or compatibilty fixes. %{versionLinkStart}Major and minor versions%{versionLinkEnd} must match.',
            ),
          };
        default:
          return null;
      }
    },
    icon() {
      return this.size === 'sm' ? null : 'upgrade';
    },
  },
  RUNNER_INSTALL_HELP_PATH,
  RUNNER_VERSION_HELP_PATH,
};
</script>
<template>
  <div v-if="badge" class="gl-display-inline-flex gl-vertical-align-bottom">
    <gl-badge
      ref="badgeRef"
      href="#"
      :variant="badge.variant"
      :size="size"
      :icon="icon"
      v-bind="$attrs"
    >
      {{ badge.label }}
    </gl-badge>
    <gl-popover triggers="focus" :target="() => $refs.badgeRef.$el" :title="badge.label">
      <gl-sprintf :message="badge.popover">
        <template #versionLink="{ content }">
          <gl-link target="_blank" :href="$options.RUNNER_VERSION_HELP_PATH">{{ content }}</gl-link>
        </template>
        <template #installLink="{ content }">
          <gl-link target="_blank" :href="$options.RUNNER_INSTALL_HELP_PATH">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-popover>
  </div>
</template>
