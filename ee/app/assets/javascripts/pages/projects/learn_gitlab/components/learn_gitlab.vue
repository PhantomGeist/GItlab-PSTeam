<script>
import { GlProgressBar, GlSprintf, GlAlert } from '@gitlab/ui';
import eventHub from '~/invite_members/event_hub';
import { s__ } from '~/locale';
import { getCookie, removeCookie, parseBoolean } from '~/lib/utils/common_utils';
import { ON_CELEBRATION_TRACK_LABEL } from '~/invite_members/constants';
import eventHubNav from '~/super_sidebar/event_hub';
import { ACTION_LABELS, INVITE_MODAL_OPEN_COOKIE } from '../constants';
import LearnGitlabSectionCard from './learn_gitlab_section_card.vue';
import UltimateTrialBenefitModal from './ultimate_trial_benefit_modal.vue';

export default {
  components: {
    GlProgressBar,
    GlSprintf,
    GlAlert,
    LearnGitlabSectionCard,
    UltimateTrialBenefitModal,
  },
  i18n: {
    title: s__('LearnGitLab|Learn GitLab'),
    description: s__(
      'LearnGitLab|Ready to get started with GitLab? Follow these steps to set up your workspace, plan and commit changes, and deploy your project.',
    ),
    percentageCompleted: s__(`LearnGitLab|%{percentage}%{percentSymbol} completed`),
    successfulInvitations: s__(
      "LearnGitLab|Your team is growing! You've successfully invited new team members to the %{projectName} project.",
    ),
    addCodeBlockTitle: s__('LearnGitLab|1. Add code to your project'),
    buildBlockTitle: s__('LearnGitLab|2. Build'),
  },
  props: {
    actions: {
      required: true,
      type: Object,
    },
    sections: {
      required: true,
      type: Array,
    },
    project: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      showSuccessfulInvitationsAlert: false,
      actionsData: this.actions,
    };
  },
  computed: {
    firstBlockSections() {
      return Object.keys(this.sections[0]);
    },
    secondBlockSections() {
      return Object.keys(this.sections[1]);
    },
    maxValue() {
      return Object.keys(this.actionsData).length;
    },
    progressValue() {
      return Object.values(this.actionsData).filter((a) => a.completed).length;
    },
    progressPercentage() {
      return Math.round((this.progressValue / this.maxValue) * 100);
    },
  },
  mounted() {
    if (this.getCookieForInviteMembers()) {
      if (this.project.showUltimateTrialBenefitModal) {
        this.$refs.ultimateTrialBenefitModal.show();
      } else {
        this.openInviteMembersModal('celebrate', ON_CELEBRATION_TRACK_LABEL);
      }
    }

    eventHub.$on('showSuccessfulInvitationsAlert', this.handleShowSuccessfulInvitationsAlert);
  },
  beforeDestroy() {
    eventHub.$off('showSuccessfulInvitationsAlert', this.handleShowSuccessfulInvitationsAlert);
  },
  methods: {
    getCookieForInviteMembers() {
      const value = parseBoolean(getCookie(INVITE_MODAL_OPEN_COOKIE));

      removeCookie(INVITE_MODAL_OPEN_COOKIE);

      return value;
    },
    openInviteMembersModal(mode, source) {
      eventHub.$emit('openModal', { mode, source });
    },
    handleShowSuccessfulInvitationsAlert() {
      this.showSuccessfulInvitationsAlert = true;
      this.markActionAsCompleted('userAdded');
    },
    actionsFor(section) {
      const actions = Object.fromEntries(
        Object.entries(this.actionsData).filter(
          ([action]) => ACTION_LABELS[action].section === section,
        ),
      );
      return actions;
    },
    svgFor(index, section) {
      return this.sections[index][section].svg;
    },
    markActionAsCompleted(completedAction) {
      Object.keys(this.actionsData).forEach((action) => {
        if (action === completedAction) {
          this.actionsData[action].completed = true;
          this.modifySidebarPercentage();
        }
      });
    },
    modifySidebarPercentage() {
      const el = document.querySelector('.sidebar-top-level-items .active .count');
      const formattedProgress = `${this.progressPercentage}%`;

      if (el) {
        el.textContent = formattedProgress;
      } else {
        // super sidebar
        eventHubNav.$emit('updatePillValue', {
          value: formattedProgress,
          itemId: 'learn_gitlab',
        });
      }
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="showSuccessfulInvitationsAlert"
      variant="success"
      class="gl-mt-5"
      @dismiss="showSuccessfulInvitationsAlert = false"
    >
      <gl-sprintf :message="$options.i18n.successfulInvitations">
        <template #projectName>
          <strong>{{ project.name }}</strong>
        </template>
      </gl-sprintf>
    </gl-alert>
    <div class="row">
      <div class="gl-mb-7 gl-ml-5">
        <h1 class="gl-font-size-h1">{{ $options.i18n.title }}</h1>
        <p class="gl-text-gray-700 gl-mb-0">{{ $options.i18n.description }}</p>
      </div>
    </div>
    <div class="gl-mb-3">
      <p class="gl-text-gray-500 gl-mb-2" data-testid="completion-percentage">
        <gl-sprintf :message="$options.i18n.percentageCompleted">
          <template #percentage>{{ progressPercentage }}</template>
          <template #percentSymbol>%</template>
        </gl-sprintf>
      </p>
      <gl-progress-bar :value="progressValue" :max="maxValue" />
    </div>

    <div class="gl-mt-6">
      <h2 class="gl-font-weight-bold gl-font-size-h2">
        {{ $options.i18n.addCodeBlockTitle }}
      </h2>
    </div>

    <div class="row">
      <div
        v-for="section in firstBlockSections"
        :key="section"
        class="gl-mt-5 col-sm-12 col-mb-6 col-lg-3"
      >
        <learn-gitlab-section-card
          :section="section"
          :svg="svgFor(0, section)"
          :actions="actionsFor(section)"
        />
      </div>
    </div>

    <div class="gl-mt-6">
      <h2 class="gl-font-weight-bold gl-font-size-h2">
        {{ $options.i18n.buildBlockTitle }}
      </h2>
    </div>

    <div class="row">
      <div
        v-for="section in secondBlockSections"
        :key="section"
        class="gl-mt-5 col-sm-12 col-mb-6 col-lg-4"
      >
        <learn-gitlab-section-card
          :section="section"
          :svg="svgFor(1, section)"
          :actions="actionsFor(section)"
        />
      </div>
    </div>
    <ultimate-trial-benefit-modal ref="ultimateTrialBenefitModal" />
  </div>
</template>
