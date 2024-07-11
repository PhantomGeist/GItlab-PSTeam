import { isEmpty, mapKeys } from 'lodash';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { RENAMED_FILTER_KEYS_DEFAULT } from 'ee/issues_analytics/constants';

/**
 * Returns an object with renamed filter keys.
 *
 * @param {Object} filters - Filters with keys to be renamed
 * @param {Object} newKeys - Map of old keys to new keys
 *
 * @returns {Object}
 */
const renameFilterKeys = (filters, newKeys) =>
  mapKeys(filters, (value, key) => newKeys[key] ?? key);

/**
 * This util method takes the global page filters and transforms parameters which
 * are not standardized between the internal issue analytics api and the public
 * issues api.
 *
 * @param {Object} filters - the global filters used to fetch issues data
 * @param {Object} renamedKeys - map of keys to be renamed
 *
 * @returns {Object} - the transformed filters for the public api
 */
export const transformFilters = (filters = {}, renamedKeys = RENAMED_FILTER_KEYS_DEFAULT) => {
  let formattedFilters = convertObjectPropsToCamelCase(filters, {
    deep: true,
    dropKeys: ['scope'],
  });

  if (!isEmpty(renamedKeys)) {
    formattedFilters = renameFilterKeys(formattedFilters, renamedKeys);
  }

  const newFilters = {};

  Object.entries(formattedFilters).forEach(([key, val]) => {
    const negatedFilterMatch = key.match(/^not\[(.+)\]/);

    if (negatedFilterMatch) {
      const negatedFilterKey = negatedFilterMatch[1];

      if (!newFilters.not) {
        newFilters.not = {};
      }

      Object.assign(newFilters.not, { [negatedFilterKey]: val });
    } else {
      newFilters[key] = val;
    }
  });

  return newFilters;
};
