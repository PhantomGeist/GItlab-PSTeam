import { nextTick } from 'vue';
import axios from 'axios';
import AxiosMockAdapter from 'axios-mock-adapter';
import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlLoadingIcon,
  GlIntersperse,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { trimText } from 'helpers/text_helper';
import LicenseToken from 'ee/dependencies/components/filtered_search/tokens/license_token.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

const TEST_GROUP_LICENSES_ENDPOINT = 'https://gitlab.com/api/v4/group/123/-/licenses';
const TEST_LICENSES = [
  {
    name: 'Apache 2.0',
    spdx_identifier: 'Apache-2.0',
  },
  {
    name: 'MIT License',
    spdx_identifier: 'MIT',
  },
];

describe('ee/dependencies/components/filtered_search/tokens/license_token.vue', () => {
  let wrapper;
  let axiosMock;

  const createAxiosMock = () => {
    axiosMock = new AxiosMockAdapter(axios);
    axiosMock.onGet(TEST_GROUP_LICENSES_ENDPOINT).reply(() => {
      return [HTTP_STATUS_OK, { licenses: TEST_LICENSES }];
    });
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(LicenseToken, {
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
      },
      provide: {
        licensesEndpoint: TEST_GROUP_LICENSES_ENDPOINT,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="view"></slot><slot name="suggestions"></slot></div>`,
        }),
        GlIntersperse,
      },
    });
  };

  beforeEach(() => {
    createAxiosMock();
    createComponent();
  });

  afterEach(() => {
    axiosMock.restore();
  });

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const isLoadingSuggestions = () => wrapper.findComponent(GlLoadingIcon).exists();
  const selectLicense = (license) => {
    findFilteredSearchToken().vm.$emit('select', license.spdx_identifier);
    return nextTick();
  };
  const searchForLicense = (searchTerm = '') => {
    findFilteredSearchToken().vm.$emit('input', { data: searchTerm });
    return waitForPromises();
  };
  // this is just an alias for waitForPromises, but it makes the test more readable
  const waitForLicensesToBeFetched = () => waitForPromises();

  describe('when the component is initially rendered', () => {
    it('shows a loading indicator while fetching the list of licenses', () => {
      expect(isLoadingSuggestions()).toBe(true);
    });

    it('shows the full list of licenses once the fetch is completed', async () => {
      searchForLicense();
      await waitForLicensesToBeFetched();

      expect(wrapper.text()).toContain(TEST_LICENSES[0].name);
      expect(wrapper.text()).toContain(TEST_LICENSES[1].name);
    });
  });

  describe('when a user enters a search term', () => {
    it('shows a loading indicator while fetching the list of licenses', async () => {
      searchForLicense(TEST_LICENSES[0].name);
      await nextTick();

      expect(isLoadingSuggestions()).toBe(true);

      await waitForLicensesToBeFetched();

      expect(isLoadingSuggestions()).toBe(false);
    });

    it('shows the filtered list of suggestions', async () => {
      await searchForLicense(TEST_LICENSES[0].name);

      expect(wrapper.text()).toContain(TEST_LICENSES[0].name);
      expect(wrapper.text()).not.toContain(TEST_LICENSES[1].name);
    });
  });

  describe('when a user selects licenses to be filtered', () => {
    beforeEach(async () => {
      await searchForLicense();
    });

    it('displays a check-icon next to the selected license', async () => {
      const findFirstSearchSuggestionIcon = () =>
        wrapper.findAllComponents(GlFilteredSearchSuggestion).at(0).findComponent(GlIcon);
      const hiddenClassName = 'gl-visibility-hidden';

      expect(findFirstSearchSuggestionIcon().classes()).toContain(hiddenClassName);

      await selectLicense(TEST_LICENSES[0]);

      expect(findFirstSearchSuggestionIcon().classes()).not.toContain(hiddenClassName);
    });

    it('shows a comma seperated list of selected licenses', async () => {
      await selectLicense(TEST_LICENSES[0]);
      await selectLicense(TEST_LICENSES[1]);

      expect(trimText(wrapper.findByTestId('selected-licenses').text())).toBe(
        `${TEST_LICENSES[0].name}, ${TEST_LICENSES[1].name}`,
      );
    });
  });
});
