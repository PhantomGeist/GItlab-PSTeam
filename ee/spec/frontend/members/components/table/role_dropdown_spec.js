import { GlCollapsibleListbox, GlListboxItem } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import LdapDropdownFooter from 'ee/members/components/action_dropdowns/ldap_dropdown_footer.vue';
import { guestOverageConfirmAction } from 'ee/members/guest_overage_confirm_action';
import waitForPromises from 'helpers/wait_for_promises';
import RoleDropdown from '~/members/components/table/role_dropdown.vue';
import { MEMBER_TYPES } from '~/members/constants';
import { upgradedMember as member } from '../../mock_data';

Vue.use(Vuex);

jest.mock('ee/members/guest_overage_confirm_action');
guestOverageConfirmAction.mockReturnValue(true);

describe('RoleDropdown', () => {
  let wrapper;
  let actions;

  const createStore = ({ updateMemberRoleReturn = Promise.resolve() } = {}) => {
    actions = {
      updateMemberRole: jest.fn(() => updateMemberRoleReturn),
    };

    return new Vuex.Store({
      modules: {
        [MEMBER_TYPES.user]: { namespaced: true, actions },
      },
    });
  };

  const createComponent = (propsData = {}, store = createStore()) => {
    wrapper = mount(RoleDropdown, {
      provide: {
        namespace: MEMBER_TYPES.user,
        group: {
          name: '',
          path: '',
        },
      },
      propsData: {
        member,
        permissions: {},
        ...propsData,
      },
      store,
    });

    return waitForPromises();
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findListboxItems = () => wrapper.findAllComponents(GlListboxItem);
  const findListboxItemByText = (text) =>
    findListboxItems().wrappers.find((item) => item.text() === text);

  describe('when member has `canOverride` permissions', () => {
    describe('when member is overridden', () => {
      it('renders LDAP dropdown footer', async () => {
        await createComponent({
          permissions: {
            canOverride: true,
          },
          member: { ...member, isOverridden: true },
        });

        expect(wrapper.findComponent(LdapDropdownFooter).exists()).toBe(true);
      });
    });

    describe('when member is not overridden', () => {
      it('disables dropdown', async () => {
        await createComponent({
          permissions: {
            canOverride: true,
          },
          member: { ...member, isOverridden: false },
        });

        expect(findListbox().props('disabled')).toBeDefined();
      });
    });
  });

  describe('when member does not have `canOverride` permissions', () => {
    it('does not render LDAP dropdown footer', async () => {
      await createComponent({
        permissions: {
          canOverride: false,
        },
      });

      expect(wrapper.findComponent(LdapDropdownFooter).exists()).toBe(false);
    });
  });

  describe('when member has `validMemberRoles`', () => {
    it('renders standard and custom roles', async () => {
      await createComponent();

      expect(findListbox().props('items')[0].text).toBe('Standard roles');
      expect(findListbox().props('items')[0].options).toHaveLength(6);
      expect(findListbox().props('items')[1].text).toBe('Custom roles based on Guest');
      expect(findListbox().props('items')[1].options).toHaveLength(2);
      expect(findListbox().props('items')[2].text).toBe('Custom roles based on Reporter');
      expect(findListbox().props('items')[2].options).toHaveLength(1);
    });

    it('calls `updateMemberRole` Vuex action', async () => {
      await createComponent();

      await findListboxItemByText('a').trigger('click');

      expect(actions.updateMemberRole).toHaveBeenCalledWith(expect.any(Object), {
        memberId: member.id,
        accessLevel: { integerValue: 10, memberRoleId: 101 },
      });
    });
  });
});
