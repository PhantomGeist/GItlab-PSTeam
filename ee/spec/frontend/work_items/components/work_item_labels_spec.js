import { GlLabel } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import WorkItemLabels from '~/work_items/components/work_item_labels.vue';
import { workItemByIidResponseFactory } from 'jest/work_items/mock_data';

Vue.use(VueApollo);

describe('WorkItemLabels component', () => {
  let wrapper;

  const findScopedLabel = () =>
    wrapper.findAllComponents(GlLabel).filter((label) => label.props('scoped'));

  const createComponent = ({
    canUpdate = true,
    workItemQueryHandler = jest.fn().mockResolvedValue(workItemByIidResponseFactory()),
  } = {}) => {
    wrapper = mount(WorkItemLabels, {
      apolloProvider: createMockApollo([[workItemByIidQuery, workItemQueryHandler]]),
      provide: {
        isGroup: false,
      },
      propsData: {
        fullPath: 'test-project-path',
        workItemId: 'gid://gitlab/WorkItem/1',
        workItemIid: '1',
        canUpdate,
      },
    });
  };

  describe('allows scoped labels', () => {
    it.each([true, false])('= %s', async (allowsScopedLabels) => {
      const workItemQueryHandler = jest
        .fn()
        .mockResolvedValue(workItemByIidResponseFactory({ allowsScopedLabels }));
      createComponent({ workItemQueryHandler });
      await waitForPromises();

      expect(findScopedLabel().exists()).toBe(allowsScopedLabels);
    });
  });
});
