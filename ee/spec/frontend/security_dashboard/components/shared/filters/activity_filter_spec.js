import { GlCollapsibleListbox, GlBadge } from '@gitlab/ui';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import ActivityFilter, {
  ITEMS,
  GROUPS,
  GROUPS_MR,
} from 'ee/security_dashboard/components/shared/filters/activity_filter.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filters/constants';

const [, ...GROUPS_WITHOUT_DEFAULT] = GROUPS;

describe('Activity Filter component', () => {
  let wrapper;

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findItem = (value) => wrapper.findByTestId(`listbox-item-${value}`);
  const findHeader = (text) => wrapper.findByTestId(`header-${text}`);
  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
  const clickItem = (value) => findItem(value).trigger('click');

  const expectSelectedItems = (values) => {
    expect(findListbox().props('selected')).toEqual(values);
  };

  const createWrapper = ({ glFeatures = {} } = {}) => {
    wrapper = mountExtended(ActivityFilter, {
      stubs: { QuerystringSync: true, GlBadge: true },
      provide: {
        glFeatures: {
          activityFilterHasMr: true,
          ...glFeatures,
        },
      },
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  describe('QuerystringSync component', () => {
    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'activity',
        value: [],
      });
    });

    it.each`
      emitted                             | expected
      ${[]}                               | ${[ALL_ID]}
      ${[ITEMS.NO_LONGER_DETECTED.value]} | ${[ITEMS.NO_LONGER_DETECTED.value]}
    `('restores selected items - $emitted', async ({ emitted, expected }) => {
      await findQuerystringSync().vm.$emit('input', emitted);

      expectSelectedItems(expected);
    });
  });

  describe('toggleText', () => {
    it(`passes '${ITEMS.NO_LONGER_DETECTED.text}' when only '${ITEMS.NO_LONGER_DETECTED.text}' is selected`, async () => {
      await clickItem(ITEMS.NO_LONGER_DETECTED.value);

      expect(findListbox().props('toggleText')).toBe(ITEMS.NO_LONGER_DETECTED.text);
    });

    it(`passes '${ITEMS.NO_LONGER_DETECTED.text} +1 more' when '${ITEMS.NO_LONGER_DETECTED.text}' and item from Issue group is selected`, async () => {
      await clickItem(ITEMS.NO_LONGER_DETECTED.value);
      await clickItem(ITEMS.HAS_ISSUE.value);

      expect(findListbox().props('toggleText')).toBe(`${ITEMS.NO_LONGER_DETECTED.text} +1 more`);
    });

    it(`passes "${ActivityFilter.i18n.allItemsText}" when no option is selected`, () => {
      expect(findListbox().props('toggleText')).toBe(ActivityFilter.i18n.allItemsText);
    });
  });

  it('renders the header text for each non default group', () => {
    GROUPS_WITHOUT_DEFAULT.forEach(({ text }) => {
      const header = findHeader(text);

      expect(header.text()).toContain(text);
    });
  });

  it('renders the badge for each group', () => {
    GROUPS_WITHOUT_DEFAULT.forEach(({ text, icon, variant }) => {
      const header = findHeader(text);

      expect(header.findComponent(GlBadge).attributes()).toMatchObject({
        icon,
        variant: variant ?? 'muted',
      });
    });
  });

  it('passes GROUPS with MR to listbox items', () => {
    expect(findListbox().props('items')).toEqual([...GROUPS, GROUPS_MR]);
  });

  it('selects and unselects an item when clicked on', async () => {
    const { value } = ITEMS.HAS_ISSUE;
    await clickItem(value);

    expectSelectedItems([value]);

    await clickItem(value);

    expectSelectedItems([ALL_ID]);
  });

  it.each(GROUPS_WITHOUT_DEFAULT.map((group) => [group.text, group]))(
    'allows only one item to be selected for the %s group',
    async (_groupName, group) => {
      for await (const { value } of group.options) {
        await clickItem(value);

        expectSelectedItems([value]);
      }
    },
  );

  it('allows multiple selection of items across groups', async () => {
    // Get the first item in each group and click on them.
    const values = GROUPS_WITHOUT_DEFAULT.map((group) => group.options[0].value);
    for await (const value of values) {
      await clickItem(value);
    }

    expectSelectedItems(values);
  });

  describe('filter-changed event', () => {
    it('emits the expected data for the all option', async () => {
      await clickItem(ALL_ID);

      expect(wrapper.emitted('filter-changed')).toHaveLength(1);
      expect(wrapper.emitted('filter-changed')[0][0]).toStrictEqual({
        hasIssues: undefined,
        hasResolution: undefined,
        hasMergeRequest: undefined,
      });
    });

    it.each`
      selectedItems                                                                                                 | hasIssues | hasResolution | hasMergeRequest
      ${[ITEMS.STILL_DETECTED.value, ITEMS.HAS_ISSUE.value, ITEMS.HAS_MERGE_REQUEST.value]}                         | ${true}   | ${false}      | ${true}
      ${[ITEMS.NO_LONGER_DETECTED.value, ITEMS.DOES_NOT_HAVE_ISSUE.value, ITEMS.DOES_NOT_HAVE_MERGE_REQUEST.value]} | ${false}  | ${true}       | ${false}
    `(
      'emits the expected data for $selectedItems',
      async ({ selectedItems, hasIssues, hasResolution, hasMergeRequest }) => {
        for await (const value of selectedItems) {
          await clickItem(value);
        }

        // Take the emit of the last item as this will include the change of all items
        const emitIndexToCheck = selectedItems.length - 1;

        expectSelectedItems(selectedItems);
        expect(wrapper.emitted('filter-changed')[emitIndexToCheck][0]).toEqual({
          hasIssues,
          hasMergeRequest,
          hasResolution,
        });
      },
    );
  });

  describe('when feature flag is disabled', () => {
    beforeEach(() => {
      createWrapper({
        glFeatures: { activityFilterHasMr: false },
      });
    });

    it('passes GROUPS to listbox items', () => {
      expect(findListbox().props('items')).toEqual(GROUPS);
    });

    it('emits the expected data for the all option', async () => {
      await clickItem(ALL_ID);

      expect(wrapper.emitted('filter-changed')).toHaveLength(1);
      expect(wrapper.emitted('filter-changed')[0][0]).toStrictEqual({
        hasIssues: undefined,
        hasResolution: undefined,
      });
    });

    it.each`
      selectedItems                                                        | hasIssues | hasResolution
      ${[ITEMS.STILL_DETECTED.value, ITEMS.HAS_ISSUE.value]}               | ${true}   | ${false}
      ${[ITEMS.NO_LONGER_DETECTED.value, ITEMS.DOES_NOT_HAVE_ISSUE.value]} | ${false}  | ${true}
    `(
      'emits the expected data for $selectedItems',
      async ({ selectedItems, hasIssues, hasResolution }) => {
        for await (const value of selectedItems) {
          await clickItem(value);
        }

        // Take the emit of the last item as this will include the change of all items
        const emitIndexToCheck = selectedItems.length - 1;

        expectSelectedItems(selectedItems);
        expect(wrapper.emitted('filter-changed')[emitIndexToCheck][0]).toEqual({
          hasIssues,
          hasResolution,
        });
      },
    );
  });
});
