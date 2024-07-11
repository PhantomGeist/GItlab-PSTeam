<script>
import { GlBadge, GlPopover, GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

const ICON_COLOR = {
  opened: 'gl-text-green-500',
  closed: 'gl-text-red-500',
  merged: 'gl-text-blue-500',
};

const ICON = {
  opened: 'issue-open-m',
  closed: 'issue-close',
  merged: 'merge',
};

export default {
  components: {
    GlBadge,
    GlIcon,
    GlPopover,
    GlLink,
    GlSprintf,
  },
  props: {
    mergeRequest: {
      type: Object,
      required: true,
    },
  },
  computed: {
    mergeRequestIdString() {
      return this.mergeRequest.securityAutoFix
        ? s__('AutoRemediation|!%{mergeRequestIid}: Auto-fix')
        : s__('AutoRemediation|!%{mergeRequestIid}');
    },
  },
  methods: {
    getIconColor(state) {
      return ICON_COLOR[state] || 'gl-text-gray-500';
    },
    getIcon(state) {
      return ICON[state] || 'issue-open-m';
    },
  },
};
</script>

<template>
  <div ref="popover" data-testid="vulnerability-solutions-bulb">
    <gl-badge ref="badge" variant="neutral" icon="merge-request" />
    <gl-popover :target="() => $refs.popover" placement="top">
      <template #title>
        <span>{{ s__('AutoRemediation| 1 Merge Request') }}</span>
      </template>
      <ul class="gl-list-style-none gl-pl-0 gl-mb-0">
        <li class="gl-align-items-center gl-display-flex gl-mb-2">
          <gl-icon
            :name="getIcon(mergeRequest.state)"
            :size="16"
            :class="getIconColor(mergeRequest.state)"
          />
          <gl-link :href="mergeRequest.webUrl" class="gl-ml-3">
            <gl-sprintf :message="mergeRequestIdString">
              <template #mergeRequestIid>{{ mergeRequest.iid }}</template>
            </gl-sprintf>
          </gl-link>
        </li>
      </ul>
    </gl-popover>
  </div>
</template>
