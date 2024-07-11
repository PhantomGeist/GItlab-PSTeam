import { GlDisclosureDropdown } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';

import EpicActionsSplitButton from 'ee/related_items_tree/components/epic_issue_actions_split_button.vue';
import createDefaultStore from 'ee/related_items_tree/store';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

import { mockParentItem } from '../mock_data';

Vue.use(Vuex);

const createComponent = ({ slots, state = {} } = {}) => {
  const store = createDefaultStore();
  store.dispatch('setInitialParentItem', {
    ...mockParentItem,
    userPermissions: {
      ...mockParentItem.userPermissions,
      canAdmin: state.canAdmin,
      canAdminRelation: state.canAdminRelation,
    },
  });

  return extendedWrapper(
    mount(EpicActionsSplitButton, {
      store,
      slots,
      propsData: {
        allowSubEpics: true,
      },
    }),
  );
};

describe('ee/related_items_tree/components/epic_issue_actions_split_button.vue', () => {
  let wrapper;

  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownSections = () => findDisclosureDropdown().props('items');
  const findDropdownItems = () => findDropdownSections().flatMap((x) => x.items);

  describe('default (canAdmin and canAdminRelation)', () => {
    beforeEach(() => {
      wrapper = createComponent({ state: { canAdmin: true, canAdminRelation: true } });
    });

    it('renders section headers', () => {
      const sections = findDropdownSections().map((x) => x.name);

      expect(sections).toEqual(['Issue', 'Epic']);
    });

    it('renders items', () => {
      const items = findDropdownItems().map((x) => x.text);

      expect(items).toEqual([
        'Add a new issue',
        'Add an existing issue',
        'Add a new epic',
        'Add an existing epic',
      ]);
    });

    it.each`
      itemText                   | event                    | args
      ${'Add a new issue'}       | ${'showCreateIssueForm'} | ${[]}
      ${'Add an existing issue'} | ${'showAddIssueForm'}    | ${[]}
      ${'Add a new epic'}        | ${'showCreateEpicForm'}  | ${[]}
      ${'Add an existing epic'}  | ${'showAddEpicForm'}     | ${[]}
    `('when $itemText clicked, emits $event', ({ itemText, event, args }) => {
      const item = findDropdownItems().find((x) => x.text === itemText);

      expect(wrapper.emitted()).toEqual({});

      item.action();

      expect(wrapper.emitted()).toEqual({
        [event]: [args],
      });
    });
  });

  describe('when cannot admin relation', () => {
    beforeEach(() => {
      wrapper = createComponent({ state: { canAdminRelation: false } });
    });

    it('does not render entire "Epic"', () => {
      const sections = findDropdownSections().map((x) => x.name);

      expect(sections).toEqual(['Issue']);
    });
  });

  describe('when cannot admin', () => {
    beforeEach(() => {
      wrapper = createComponent({ state: { canAdmin: false, canAdminRelation: true } });
    });

    it('does not render "Add a new epic" action', () => {
      const actionTexts = findDropdownItems().map((x) => x.text);

      expect(actionTexts).toEqual([
        'Add a new issue',
        'Add an existing issue',
        'Add an existing epic',
      ]);
    });
  });
});
