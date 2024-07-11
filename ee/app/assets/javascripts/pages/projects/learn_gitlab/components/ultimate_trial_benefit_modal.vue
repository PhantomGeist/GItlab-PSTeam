<script>
import { GlModal, GlIcon, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import Tracking from '~/tracking';
import ModalConfetti from '~/invite_members/components/confetti.vue';
import { ULTIMATE_TRIAL_BENEFIT_MODAL } from '../constants';

export default {
  name: 'UltimateTrialBenefitModal',
  components: { GlModal, GlIcon, GlButton, ModalConfetti },
  mixins: [
    Tracking.mixin({
      experiment: ULTIMATE_TRIAL_BENEFIT_MODAL,
      category: ULTIMATE_TRIAL_BENEFIT_MODAL,
    }),
  ],
  i18n: {
    modalTitle: s__('Trials|Congrats on starting your 30-day free trial!'),
    modalSubTitle: s__("Trials|With GitLab Ultimate, you'll have access to:"),
    modalCTA: s__('LearnGitLab|Start Learning GitLab'),
    trialBenefits: [
      s__('TrialBenefits|Suggested Reviewers'),
      s__('TrialBenefits|Dynamic Applications Security Testing'),
      s__('TrialBenefits|Security Dashboards'),
      s__('TrialBenefits|Vulnerability Management'),
      s__('TrialBenefits|Container Scanning'),
      s__('TrialBenefits|Static Application Security Testing'),
      s__('TrialBenefits|Multi-Level Epics'),
    ],
    bulletsLabel: s__('Trials|Trials benefits'),
  },
  mounted() {
    this.track('render_modal');
  },
  methods: {
    show() {
      this.$refs.modal.show();
    },
    onConfirm() {
      this.$refs.modal.hide();
      this.track('click_link', { label: 'start_learning_gitlab' });
    },
    onClose() {
      this.track('click_x');
    },
  },
};
</script>

<template>
  <gl-modal ref="modal" modal-id="ultimateTrialBenefitModal" size="sm" @close="onClose">
    <template #modal-title>
      <h2 class="gl-font-size-h2 gl-mt-2">
        <gl-emoji data-name="tada" class="gl-mr-2" />
        {{ $options.i18n.modalTitle }}
      </h2>
    </template>
    <p>{{ $options.i18n.modalSubTitle }}</p>
    <ul class="gl-list-style-none gl-mb-0 gl-px-0">
      <li v-for="benefit in $options.i18n.trialBenefits" :key="benefit" class="gl-my-2">
        <gl-icon
          :aria-label="$options.i18n.bulletsLabel"
          name="check-circle-filled"
          class="gl-text-green-500 gl-mr-2"
        />
        {{ benefit }}
      </li>
    </ul>
    <template #modal-footer>
      <gl-button category="primary" variant="confirm" @click="onConfirm">{{
        $options.i18n.modalCTA
      }}</gl-button>
      <modal-confetti />
    </template>
  </gl-modal>
</template>
