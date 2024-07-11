import { mapProjectsUsageResponse } from 'ee/usage_quotas/product_analytics/graphql/utils';
import { getProjectsUsageDataResponse, getProjectUsage } from './mock_data';

describe('Product analytics usage quota graphql utils', () => {
  describe('mapProjectsUsageResponse', () => {
    it('returns expected value when there are no projects', () => {
      const response = getProjectsUsageDataResponse([], []);

      const mapped = mapProjectsUsageResponse(response);

      expect(mapped).toEqual([]);
    });

    it('returns expected value when there are no onboarded projects', () => {
      const response = getProjectsUsageDataResponse(
        [getProjectUsage({ id: 1, name: 'not onboarded', numEvents: null })],
        [getProjectUsage({ id: 1, name: 'not onboarded', numEvents: null })],
      );

      const mapped = mapProjectsUsageResponse(response);

      expect(mapped).toEqual([]);
    });

    it('returns expected value when a project is onboarded in the current month', () => {
      const response = getProjectsUsageDataResponse(
        [getProjectUsage({ id: 1, name: 'just onboarded', numEvents: 1 })],
        [getProjectUsage({ id: 1, name: 'just onboarded', numEvents: null })],
      );

      const mapped = mapProjectsUsageResponse(response);

      expect(mapped).toEqual([
        {
          id: 1,
          name: 'just onboarded',
          webUrl: '/just onboarded',
          avatarUrl: '/just onboarded.jpg',
          currentEvents: 1,
          previousEvents: 0,
        },
      ]);
    });

    it('returns expected value when there is current but no previous projects', () => {
      const response = getProjectsUsageDataResponse(
        [getProjectUsage({ id: 1, name: 'onboarded', numEvents: 1234 })],
        [],
      );

      const mapped = mapProjectsUsageResponse(response);

      expect(mapped).toEqual([
        {
          id: 1,
          name: 'onboarded',
          webUrl: '/onboarded',
          avatarUrl: '/onboarded.jpg',
          currentEvents: 1234,
          previousEvents: 0,
        },
      ]);
    });

    it('returns expected value when there are previous but no current projects', () => {
      const response = getProjectsUsageDataResponse(
        [],
        [getProjectUsage({ id: 1, name: 'onboarded', numEvents: 1234 })],
      );

      const mapped = mapProjectsUsageResponse(response);

      expect(mapped).toEqual([
        {
          id: 1,
          name: 'onboarded',
          webUrl: '/onboarded',
          avatarUrl: '/onboarded.jpg',
          currentEvents: 0,
          previousEvents: 1234,
        },
      ]);
    });

    it('returns expected value when there are both current and previous projects', () => {
      const response = getProjectsUsageDataResponse(
        [getProjectUsage({ id: 1, name: 'onboarded', numEvents: 1234 })],
        [getProjectUsage({ id: 1, name: 'onboarded', numEvents: 987 })],
      );

      const mapped = mapProjectsUsageResponse(response);

      expect(mapped).toEqual([
        {
          id: 1,
          name: 'onboarded',
          webUrl: '/onboarded',
          avatarUrl: '/onboarded.jpg',
          currentEvents: 1234,
          previousEvents: 987,
        },
      ]);
    });

    it('returns expected value when there are mixed projects', () => {
      const response = getProjectsUsageDataResponse(
        [
          getProjectUsage({ id: 1, name: 'onboarded', numEvents: 1234 }),
          getProjectUsage({ id: 2, name: 'current only project', numEvents: 55 }),
          getProjectUsage({ id: 3, name: 'not onboarded', numEvents: null }),
        ],
        [
          getProjectUsage({ id: 1, name: 'onboarded', numEvents: 987 }),
          getProjectUsage({ id: 4, name: 'previous only project', numEvents: 777 }),
          getProjectUsage({ id: 3, name: 'not onboarded', numEvents: null }),
        ],
      );

      const mapped = mapProjectsUsageResponse(response);

      expect(mapped).toEqual([
        {
          id: 1,
          name: 'onboarded',
          webUrl: '/onboarded',
          avatarUrl: '/onboarded.jpg',
          currentEvents: 1234,
          previousEvents: 987,
        },
        {
          id: 2,
          name: 'current only project',
          webUrl: '/current only project',
          avatarUrl: '/current only project.jpg',
          currentEvents: 55,
          previousEvents: 0,
        },
        {
          id: 4,
          name: 'previous only project',
          webUrl: '/previous only project',
          avatarUrl: '/previous only project.jpg',
          currentEvents: 0,
          previousEvents: 777,
        },
      ]);
    });
  });
});
