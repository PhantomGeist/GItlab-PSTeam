import {
  GlPagination,
  GlButton,
  GlTable,
  GlAvatarLink,
  GlAvatarLabeled,
  GlBadge,
  GlModal,
} from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import SubscriptionUserList from 'ee/usage_quotas/seats/components/subscription_user_list.vue';
import {
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  SORT_OPTIONS,
} from 'ee/usage_quotas/seats/constants';
import { mockTableItems } from 'ee_jest/usage_quotas/seats/mock_data';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import SearchAndSortBar from 'ee/usage_quotas/components/search_and_sort_bar/search_and_sort_bar.vue';

Vue.use(Vuex);

const actionSpies = {
  setBillableMemberToRemove: jest.fn(),
  setSearchQuery: jest.fn(),
};

const MOCK_SEAT_USAGE_EXPORT_PATH = '/groups/test_group/-/seat_usage.csv';

const fakeStore = ({ initialState, initialGetters }) =>
  new Vuex.Store({
    actions: actionSpies,
    getters: {
      tableItems: () => mockTableItems,
      isLoading: () => false,
      ...initialGetters,
    },
    state: {
      hasError: false,
      namespaceId: '1',
      total: 300,
      page: 1,
      perPage: 5,
      sort: 'last_activity_on_desc',
      seatUsageExportPath: MOCK_SEAT_USAGE_EXPORT_PATH,
      ...initialState,
    },
  });

describe('Subscription User List', () => {
  let wrapper;

  const createComponent = ({
    initialState = {},
    mountFn = shallowMount,
    initialGetters = {},
  } = {}) => {
    wrapper = extendedWrapper(
      mountFn(SubscriptionUserList, {
        store: fakeStore({ initialState, initialGetters }),
      }),
    );
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findExportButton = () => wrapper.findByTestId('export-button');
  const findSearchAndSortBar = () => wrapper.findComponent(SearchAndSortBar);
  const findPagination = () => wrapper.findComponent(GlPagination);
  const findAllRemoveUserItems = () => wrapper.findAllByTestId('remove-user');
  const findErrorModal = () => wrapper.findComponent(GlModal);

  const serializeUser = (rowWrapper) => {
    const avatarLink = rowWrapper.findComponent(GlAvatarLink);
    const avatarLabeled = rowWrapper.findComponent(GlAvatarLabeled);

    return {
      avatarLink: {
        href: avatarLink.attributes('href'),
        alt: avatarLink.attributes('alt'),
      },
      avatarLabeled: {
        src: avatarLabeled.attributes('src'),
        size: avatarLabeled.attributes('size'),
        text: avatarLabeled.text(),
      },
    };
  };

  const serializeTableRow = (rowWrapper) => {
    const emailWrapper = rowWrapper.find('[data-testid="email"]');

    return {
      user: serializeUser(rowWrapper),
      email: emailWrapper.text(),
      tooltip: emailWrapper.find('span').attributes('title'),
      removeUserButtonExists: rowWrapper.findComponent(GlButton).exists(),
      lastActivityOn: rowWrapper.find('[data-testid="last_activity_on"]').text(),
      lastLoginAt: rowWrapper.find('[data-testid="last_login_at"]').text(),
    };
  };

  const findSerializedTable = (tableWrapper) => {
    return tableWrapper.findAll('tbody tr').wrappers.map(serializeTableRow);
  };

  describe('renders', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mount,
        initialGetters: {
          tableItems: () => mockTableItems,
        },
      });
    });

    describe('export button', () => {
      it('has the correct href', () => {
        expect(findExportButton().attributes().href).toBe(MOCK_SEAT_USAGE_EXPORT_PATH);
      });
    });

    describe('table content', () => {
      it('renders the correct data', () => {
        const serializedTable = findSerializedTable(findTable());

        expect(serializedTable).toMatchSnapshot();
      });
    });

    it('pagination is rendered and passed correct values', () => {
      const pagination = findPagination();

      expect(pagination.props()).toMatchObject({
        perPage: 5,
        totalItems: 300,
      });
    });

    describe('with error modal', () => {
      it('does not render the model if the user is not removable', async () => {
        await findAllRemoveUserItems().at(0).trigger('click');

        expect(findErrorModal().html()).toBe('');
      });

      it('renders the error modal if the user is removable', async () => {
        await findAllRemoveUserItems().at(2).trigger('click');

        expect(findErrorModal().text()).toContain(CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT);
      });
    });

    describe('members avatar', () => {
      it('shows the correct avatarLinks length', () => {
        const avatarLinks = findTable().findAllComponents(GlAvatarLink);

        expect(avatarLinks.length).toBe(6);
      });

      it.each(['group_invite', 'project_invite'])(
        'shows the correct badge for membership_type %s',
        (membershipType) => {
          const avatarLinks = findTable().findAllComponents(GlAvatarLink);
          const badgeText = (
            membershipType.charAt(0).toUpperCase() + membershipType.slice(1)
          ).replace('_', ' ');

          avatarLinks.wrappers.forEach((avatarLinkWrapper) => {
            const currentMember = mockTableItems.find(
              (item) => item.user.name === avatarLinkWrapper.attributes().alt,
            );

            if (membershipType === currentMember.user.membership_type) {
              expect(avatarLinkWrapper.findComponent(GlBadge).text()).toBe(badgeText);
            }
          });
        },
      );
    });

    describe('members details', () => {
      it.each`
        membershipType      | shouldShowDetails
        ${'project_invite'} | ${false}
        ${'group_invite'}   | ${false}
        ${'project_member'} | ${true}
        ${'group_member'}   | ${true}
      `(
        'when membershipType is $membershipType, shouldShowDetails should be $shouldShowDetails',
        ({ membershipType, shouldShowDetails }) => {
          mockTableItems.forEach((item) => {
            const detailsExpandButtons = findTable().find(
              `[data-testid="toggle-seat-usage-details-${item.user.id}"]`,
            );

            if (membershipType === item.user.membership_type) {
              expect(detailsExpandButtons.exists()).toBe(shouldShowDetails);
            }
          });
        },
      );
    });
  });

  describe('Loading state', () => {
    describe('When nothing is loading', () => {
      beforeEach(() => {
        createComponent();
      });

      it('displays the table in a non-busy state', () => {
        expect(findTable().attributes('busy')).toBe(undefined);
      });
    });

    describe.each([
      [true, false],
      [false, true],
    ])('Busy when isLoading=%s and hasError=%s', (isLoading, hasError) => {
      beforeEach(() => {
        createComponent({
          initialGetters: { isLoading: () => isLoading },
          initialState: { hasError },
        });
      });

      it('displays table in busy state', () => {
        expect(findTable().attributes('busy')).toBe('true');
      });
    });
  });

  describe('search box', () => {
    beforeEach(() => {
      createComponent();
    });

    it('input event triggers the setSearchQuery action', () => {
      const SEARCH_STRING = 'search string';

      findSearchAndSortBar().vm.$emit('onFilter', SEARCH_STRING);

      expect(actionSpies.setSearchQuery).toHaveBeenCalledTimes(1);
      expect(actionSpies.setSearchQuery).toHaveBeenCalledWith(expect.any(Object), SEARCH_STRING);
    });

    it('contains the correct sort options', () => {
      expect(findSearchAndSortBar().props('sortOptions')).toMatchObject(SORT_OPTIONS);
    });
  });
});
