import Vue from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlButton, GlModal } from '@gitlab/ui';
import UltimateTrialBenefitModal from 'ee/pages/projects/learn_gitlab/components/ultimate_trial_benefit_modal.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { ULTIMATE_TRIAL_BENEFIT_MODAL } from 'ee/pages/projects/learn_gitlab/constants';
import ModalConfetti from '~/invite_members/components/confetti.vue';
import { stubComponent } from 'helpers/stub_component';

Vue.config.ignoredElements = ['gl-emoji'];

describe('Ultimate Trial Benefit Modal', () => {
  let wrapper;
  let hideMock;

  const createWrapper = () => {
    wrapper = shallowMount(UltimateTrialBenefitModal, {
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: `
            <div>
              <slot></slot>
              <slot name="modal-footer"></slot>
            </div>
          `,
          methods: {
            hide: hideMock,
          },
        }),
      },
    });
  };

  beforeEach(() => {
    hideMock = jest.fn();
  });

  it('should render correctly', () => {
    createWrapper();

    expect(wrapper.findAll('li').length).toBe(7);
    expect(wrapper.findComponent(ModalConfetti).exists()).toBe(true);
  });

  describe('snowplow tracking', () => {
    let trackingSpy;
    const category = ULTIMATE_TRIAL_BENEFIT_MODAL;

    beforeEach(() => {
      trackingSpy = mockTracking(ULTIMATE_TRIAL_BENEFIT_MODAL, wrapper.element, jest.spyOn);

      createWrapper();
    });

    afterEach(() => {
      unmockTracking();
    });

    it('should track the render_modal event on mount', () => {
      expect(trackingSpy).toHaveBeenCalledWith(ULTIMATE_TRIAL_BENEFIT_MODAL, 'render_modal', {
        category,
      });
    });

    it('should call hide method and track the click_link event when CTA is clicked', () => {
      wrapper.findComponent(GlButton).vm.$emit('click');

      expect(hideMock).toHaveBeenCalled();
      expect(trackingSpy.mock.calls[1]).toEqual([
        ULTIMATE_TRIAL_BENEFIT_MODAL,
        'click_link',
        { category, label: 'start_learning_gitlab' },
      ]);
    });

    it('should track the click_x event when modal is closed', () => {
      wrapper.findComponent(GlModal).vm.$emit('close');

      expect(trackingSpy.mock.calls[1]).toEqual([
        ULTIMATE_TRIAL_BENEFIT_MODAL,
        'click_x',
        { category },
      ]);
    });
  });
});
