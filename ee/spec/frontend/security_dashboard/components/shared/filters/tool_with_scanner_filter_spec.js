import { GlCollapsibleListbox } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ToolWithScannerFilter from 'ee/security_dashboard/components/shared/filters/tool_with_scanner_filter.vue';
import { REPORT_TYPES_DEFAULT } from 'ee/security_dashboard/store/constants';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filters/constants';
import {
  MOCK_SCANNERS,
  MOCK_SCANNERS_WITH_CLUSTER_IMAGE_SCANNING,
  MOCK_SCANNERS_WITH_CUSTOM_VENDOR,
} from './mock_data';

const MANUALLY_ADDED_OPTION = {
  text: 'Manually added',
  value: 'gitlab-manual-vulnerability-report',
};

describe('Tool With Scanner Filter component', () => {
  let wrapper;

  const createWrapper = ({ scanners = MOCK_SCANNERS } = {}) => {
    wrapper = mountExtended(ToolWithScannerFilter, {
      provide: { scanners },
      stubs: {
        QuerystringSync: true,
      },
    });
  };

  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);

  const clickDropdownItem = async (dropdownValue) => {
    await findListBox().vm.$emit('select', [dropdownValue]);
  };

  const clickAllItem = async () => {
    await findListBox().vm.$emit('select', [ALL_ID]);
  };

  const expectSelectedItems = (ids) => {
    expect(findListBox().props('selected')).toMatchObject(ids);
  };

  const expectFilterChanged = (expected) => {
    expect(wrapper.emitted('filter-changed')[0][0]).toEqual(expected);
  };

  const findDropdownItemByValue = (value) => {
    let items = findListBox().props('items');

    // In this case we have multiple vendors
    if (items[0]?.textSrOnly) {
      items = items.flatMap((item) => item.options);
    }

    return items.find((item) => item.value === value);
  };

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('QuerystringSync component', () => {
      it('has expected props', () => {
        expect(findQuerystringSync().props()).toMatchObject({
          querystringKey: 'scanner',
          value: [],
        });
      });

      it('receives empty array when All Statuses option is clicked', async () => {
        // Click on another item first so that we can verify clicking on the ALL item changes it.
        await clickDropdownItem('eslint');

        // Now click ALL
        await clickAllItem();

        expect(findQuerystringSync().props('value')).toEqual([]);
      });

      it.each`
        emitted                           | expected
        ${['GitLab.SAST', 'GitLab.DAST']} | ${['GitLab.SAST', 'GitLab.DAST']}
        ${['GitLab.SAST', 'Custom.SAST']} | ${['GitLab.SAST', 'Custom.SAST']}
        ${[]}                             | ${[ALL_ID]}
      `('restores selected items - $emitted', async ({ emitted, expected }) => {
        findQuerystringSync().vm.$emit('input', emitted);
        await nextTick();

        expectSelectedItems(expected);
      });
    });

    describe('default view', () => {
      it('shows the label', () => {
        expect(wrapper.find('label').text()).toBe(ToolWithScannerFilter.i18n.label);
      });

      it('shows the dropdown with correct header text', () => {
        expect(findListBox().props('headerText')).toBe(ToolWithScannerFilter.i18n.label);
      });
    });
  });

  describe('dropdown items', () => {
    const getItemsExceptAll = () => findListBox().props('items').slice(1);

    beforeEach(() => {
      createWrapper();
    });

    it('shows the report type as the header', () => {
      const reportTypes = Object.values(REPORT_TYPES_DEFAULT);
      const items = getItemsExceptAll().map((item) => item.text);

      expect(items).toEqual(expect.arrayContaining(reportTypes));
    });

    it('does not show CLUSTER_IMAGE_SCANNING dropdown item', () => {
      const scanners = [...MOCK_SCANNERS, ...MOCK_SCANNERS_WITH_CLUSTER_IMAGE_SCANNING];
      const [{ external_id }] = MOCK_SCANNERS_WITH_CLUSTER_IMAGE_SCANNING;

      createWrapper({ scanners });

      const items = getItemsExceptAll().flatMap((item) => item.options);

      expect(items).toHaveLength(MOCK_SCANNERS.length);
      expect(findDropdownItemByValue(external_id)).toBeUndefined();
    });

    it('shows the "Manually added" item', () => {
      createWrapper();

      expect(findDropdownItemByValue(MANUALLY_ADDED_OPTION.value)).toMatchObject({
        text: MANUALLY_ADDED_OPTION.text,
        value: MANUALLY_ADDED_OPTION.value,
      });
    });

    it('shows the scanners for each report type', () => {
      const items = getItemsExceptAll().flatMap((item) => item.options);

      expect(items).toHaveLength(MOCK_SCANNERS.length);
    });

    it.each(MOCK_SCANNERS.map(({ vendor, external_id: externalId }) => [externalId, vendor]))(
      'shows the correct scanner for %s',
      (externalId, vendor) => {
        const { name } = MOCK_SCANNERS.find((s) => s.external_id === externalId);
        const expectedText = vendor === 'GitLab' ? name : `${name} (${vendor})`;

        expect(findDropdownItemByValue(externalId)).toEqual({
          text: expectedText,
          value: externalId,
        });
      },
    );

    it('does not show report types without a scanner', () => {
      createWrapper({ scanners: MOCK_SCANNERS_WITH_CUSTOM_VENDOR });
      const itemNames = getItemsExceptAll().map((item) => item.text);

      expect(itemNames).toEqual(['SAST']);
    });
  });

  describe('filter-changed event', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits the default presets when nothing is selected', async () => {
      await clickAllItem();

      expectFilterChanged({ scanner: [] });
    });

    it("emits custom Manually added's external id", async () => {
      await clickDropdownItem(MANUALLY_ADDED_OPTION.value);

      expectFilterChanged({ scanner: [MANUALLY_ADDED_OPTION.value] });
    });

    it.each(['eslint', 'gitleaks'])(
      "emits the scanner's external id '%s' when it is selected",
      async (externalId) => {
        await clickDropdownItem(externalId);

        expectFilterChanged({ scanner: [externalId] });
      },
    );
  });
});
