<script>
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
  GlIntersperse,
} from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    GlIntersperse,
  },
  inject: ['licensesEndpoint'],
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      licenses: [],
      searchTerm: '',
      selectedLicenseSpdxIds: this.value.data ? this.value.data.split(',') : [],
      isLoadingLicenses: false,
    };
  },
  computed: {
    filteredLicenses() {
      return this.licenses.filter(
        (license) =>
          license.name.toLowerCase().includes(this.searchTerm) ||
          this.selectedLicenseSpdxIds.includes(license.spdxIdentifier),
      );
    },
    selectedLicenses() {
      return this.licenses.filter((license) =>
        this.selectedLicenseSpdxIds.includes(license.spdxIdentifier),
      );
    },
  },
  created() {
    this.fetchLicenses();
  },
  methods: {
    setSearchTerm({ data }) {
      // the data can be either a string or an array, in which case we don't want to perform the search
      if (typeof data === 'string') {
        this.searchTerm = data.toLowerCase();
      }
    },
    async fetchLicenses() {
      this.isLoadingLicenses = true;

      try {
        const {
          data: { licenses },
        } = await axios.get(this.licensesEndpoint);

        // we need to wrap the license names in quotes to mark it as one value
        // otherwise the filtered search will split the string on spaces
        this.licenses = licenses.map((license) =>
          convertObjectPropsToCamelCase(license, { deep: true }),
        );
      } catch (e) {
        createAlert({
          message: s__('Dependencies|There was a problem fetching the licenses for this group.'),
        });
      } finally {
        this.isLoadingLicenses = false;
      }
    },
    toggleSelectedLicense(spdxIdentifier) {
      if (this.selectedLicenseSpdxIds.includes(spdxIdentifier)) {
        this.selectedLicenseSpdxIds = this.selectedLicenseSpdxIds.filter(
          (v) => v !== spdxIdentifier,
        );
      } else {
        this.selectedLicenseSpdxIds.push(spdxIdentifier);
      }
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedLicenseSpdxIds"
    v-on="$listeners"
    @select="toggleSelectedLicense"
    @input="setSearchTerm"
  >
    <template #view>
      <gl-intersperse data-testid="selected-licenses">
        <span v-for="selectedLicense in selectedLicenses" :key="selectedLicense.spdxIdentifier">{{
          selectedLicense.name
        }}</span>
      </gl-intersperse>
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoadingLicenses" size="sm" />
      <template v-else>
        <gl-filtered-search-suggestion
          v-for="license in filteredLicenses"
          :key="license.spdxIdentifier"
          :value="license.spdxIdentifier"
        >
          <div class="gl-display-flex gl-align-items-center">
            <gl-icon
              v-if="config.multiSelect"
              data-testid="check-icon"
              name="check"
              class="gl-mr-3 gl-flex-shrink-0 gl-text-gray-700"
              :class="{
                'gl-visibility-hidden': !selectedLicenseSpdxIds.includes(license.spdxIdentifier),
              }"
            />
            <span>{{ license.name }}</span>
          </div>
        </gl-filtered-search-suggestion>
      </template>
    </template>
  </gl-filtered-search-token>
</template>
