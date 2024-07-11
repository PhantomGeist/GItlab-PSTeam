import { projectsUsageDataValidator } from 'ee/usage_quotas/product_analytics/components/utils';

describe('Product analytics usage quota component utils', () => {
  describe('projectsUsageDataValidator', () => {
    it('returns true for empty array', () => {
      const result = projectsUsageDataValidator([]);

      expect(result).toBe(true);
    });

    it('returns true when all items have all properties', () => {
      const result = projectsUsageDataValidator([
        {
          name: 'some project',
          currentEvents: 1,
          previousEvents: 1,
        },
        {
          name: 'another project',
          currentEvents: 2,
          previousEvents: 2,
        },
      ]);

      expect(result).toBe(true);
    });

    it('returns false when given null', () => {
      const result = projectsUsageDataValidator(null);

      expect(result).toBe(false);
    });

    it('returns false when one item is invalid', () => {
      const result = projectsUsageDataValidator([
        {
          name: 'some project',
          currentEvents: 1,
          previousEvents: 1,
        },
        {
          currentEvents: 2,
          previousEvents: 2,
        },
      ]);

      expect(result).toBe(false);
    });

    it('returns false when an item property is missing', () => {
      const result = projectsUsageDataValidator([
        {
          currentEvents: 1,
          previousEvents: 1,
        },
      ]);

      expect(result).toBe(false);
    });

    it.each([
      {
        currentEvents: 1,
        previousEvents: 1,
      },
      {
        name: 'some project',
        previousEvents: 1,
      },
      {
        name: 'some project',
        currentEvents: 1,
      },
    ])('returns false when an item property is missing', (testCase) => {
      const result = projectsUsageDataValidator([testCase]);

      expect(result).toBe(false);
    });

    it.each([
      {
        name: 12345,
        currentEvents: 1,
        previousEvents: 1,
      },
      {
        name: 'some project',
        currentEvents: 'invalid',
        previousEvents: 1,
      },
      {
        name: 'some project',
        currentEvents: 1,
        previousEvents: 'invalid',
      },
    ])('returns false when an item property is the wrong type', (testCase) => {
      const result = projectsUsageDataValidator([testCase]);

      expect(result).toBe(false);
    });
  });
});
