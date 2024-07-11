import { GlFormGroup, GlBadge, GlCollapsibleListbox } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount, mount } from '@vue/test-utils';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import waitForPromises from 'helpers/wait_for_promises';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import {
  HEALTH_STATUS_AT_RISK,
  HEALTH_STATUS_I18N_NONE,
  HEALTH_STATUS_NEEDS_ATTENTION,
  HEALTH_STATUS_ON_TRACK,
  healthStatusTextMap,
} from 'ee/sidebar/constants';

import {
  updateWorkItemMutationResponse,
  workItemByIidResponseFactory,
} from 'jest/work_items/mock_data';

describe('WorkItemHealthStatus component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemId = 'gid://gitlab/WorkItem/1';
  const workItemType = 'Task';
  const workItemQueryResponse = workItemByIidResponseFactory({ canUpdate: true, canDelete: true });
  const workItemQueryHandler = jest.fn().mockResolvedValue(workItemQueryResponse);

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findBadge = () => wrapper.findComponent(GlBadge);

  const createComponent = ({
    canUpdate = true,
    hasIssuableHealthStatusFeature = true,
    healthStatus,
    mutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse),
    mountFn = shallowMount,
  } = {}) => {
    wrapper = mountFn(WorkItemHealthStatus, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, workItemQueryHandler],
        [updateWorkItemMutation, mutationHandler],
      ]),
      propsData: {
        canUpdate,
        healthStatus,
        workItemId,
        workItemIid: '1',
        workItemType,
      },
      provide: {
        hasIssuableHealthStatusFeature,
      },
    });
  };

  describe('`hasIssuableHealthStatusFeature` licensed feature', () => {
    describe.each`
      description             | hasIssuableHealthStatusFeature | exists
      ${'when available'}     | ${true}                        | ${true}
      ${'when not available'} | ${false}                       | ${false}
    `('$description', ({ hasIssuableHealthStatusFeature, exists }) => {
      it(`${hasIssuableHealthStatusFeature ? 'renders' : 'does not render'} component`, () => {
        createComponent({ hasIssuableHealthStatusFeature });

        expect(findFormGroup().exists()).toBe(exists);
      });
    });
  });

  describe('update permissions', () => {
    describe.each`
      description                     | canUpdate | exists
      ${'when allowed to update'}     | ${true}   | ${true}
      ${'when not allowed to update'} | ${false}  | ${false}
    `('$description', ({ canUpdate, exists }) => {
      it(`${canUpdate ? 'renders' : 'does not render'} the dropdown`, () => {
        createComponent({ canUpdate });

        expect(findListbox().exists()).toBe(exists);
      });
    });
  });

  describe('health status rendering', () => {
    describe('correct text', () => {
      it.each`
        healthStatus                     | text
        ${HEALTH_STATUS_ON_TRACK}        | ${healthStatusTextMap[HEALTH_STATUS_ON_TRACK]}
        ${HEALTH_STATUS_NEEDS_ATTENTION} | ${healthStatusTextMap[HEALTH_STATUS_NEEDS_ATTENTION]}
        ${HEALTH_STATUS_AT_RISK}         | ${healthStatusTextMap[HEALTH_STATUS_AT_RISK]}
        ${null}                          | ${HEALTH_STATUS_I18N_NONE}
      `('renders "$text" when health status = "$healthStatus"', ({ healthStatus, text }) => {
        createComponent({ healthStatus, mountFn: mount });

        expect(wrapper.text()).toContain(text);
      });
    });

    describe('badge renders correct variant', () => {
      it.each`
        healthStatus                     | variant
        ${HEALTH_STATUS_ON_TRACK}        | ${'success'}
        ${HEALTH_STATUS_NEEDS_ATTENTION} | ${'warning'}
        ${HEALTH_STATUS_AT_RISK}         | ${'danger'}
      `('uses "$variant" when health status = "$healthStatus"', ({ healthStatus, variant }) => {
        createComponent({ healthStatus, mountFn: mount });

        expect(findBadge().props('variant')).toBe(variant);
      });
    });
  });

  describe('health status input', () => {
    it.each`
      selected            | expectedStatus
      ${'empty'}          | ${null}
      ${'onTrack'}        | ${'onTrack'}
      ${'needsAttention'} | ${'needsAttention'}
      ${'atRisk'}         | ${'atRisk'}
    `('calls mutation with health status = "$expectedStatus"', ({ selected, expectedStatus }) => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      createComponent({
        mutationHandler: mutationSpy,
      });

      findListbox().vm.$emit('select', selected);

      expect(mutationSpy).toHaveBeenCalledWith({
        input: {
          id: workItemId,
          healthStatusWidget: {
            healthStatus: expectedStatus,
          },
        },
      });
    });

    it('emits an error when there is a GraphQL error', async () => {
      const response = {
        data: {
          workItemUpdate: {
            errors: ['Error!'],
            workItem: {},
          },
        },
      };
      createComponent({
        mutationHandler: jest.fn().mockResolvedValue(response),
      });

      findListbox().vm.$emit('select', 'onTrack');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
    });

    it('emits an error when there is a network error', async () => {
      createComponent({
        mutationHandler: jest.fn().mockRejectedValue(new Error()),
      });

      findListbox().vm.$emit('select', 'onTrack');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
    });

    it('tracks updating the health status', () => {
      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      createComponent();

      findListbox().vm.$emit('select', 'onTrack');

      expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_health_status', {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_health_status',
        property: 'type_Task',
      });
    });
  });
});
