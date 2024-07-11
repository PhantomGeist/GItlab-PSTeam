import { transformFilters } from 'ee/issues_analytics/utils';
import { mockOriginalFilters, mockFilters } from './mock_data';

describe('Issues Analytics utils', () => {
  describe('transformFilters', () => {
    it('transforms the object keys as expected', () => {
      const filters = transformFilters(mockOriginalFilters);

      expect(filters).toEqual(mockFilters);
    });

    it('groups negated filters into a single `not` object', () => {
      const originalNegatedFilters = {
        'not[author_username]': 'john_smith',
        'not[label_name]': ['Phant'],
        'not[epic_id]': '4',
      };

      const negatedFilters = {
        not: {
          authorUsername: 'john_smith',
          labelName: ['Phant'],
          epicId: '4',
        },
      };

      const filters = transformFilters({ ...mockOriginalFilters, ...originalNegatedFilters });

      expect(filters).toEqual({ ...mockFilters, ...negatedFilters });
    });

    it('renames keys when new key names are provided', () => {
      const newKeys = { labelName: 'labelNames', assigneeUsername: 'assigneeUsernames' };
      const originalFilters = { label_name: [], assignee_username: [], author_username: 'bob' };
      const newFilters = { labelNames: [], assigneeUsernames: [], authorUsername: 'bob' };
      const filters = transformFilters(originalFilters, newKeys);

      expect(filters).toEqual(newFilters);
    });
  });
});
