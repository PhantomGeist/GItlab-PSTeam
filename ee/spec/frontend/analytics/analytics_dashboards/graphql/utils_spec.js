import { extractNamespaceData } from 'ee/analytics/analytics_dashboards/graphql/utils';

describe('Analytics Dashboards graphql utils', () => {
  describe('extractNamespaceData', () => {
    const mockGroup = { id: 'some-group', __typename: 'Group' };
    const mockProject = { id: 'some-project', __typename: 'Project' };
    const mockPersonalNamespace = { id: 'some-project', __typename: 'Namespace' };
    let res;

    it('returns the group data if available', () => {
      res = extractNamespaceData({ group: mockGroup });

      expect(res).toBe(mockGroup);
      expect(res).not.toBe(mockProject);
    });

    it('returns the project data if available', () => {
      res = extractNamespaceData({ project: mockProject });

      expect(res).toBe(mockProject);
    });

    it('returns the project data if given both a group and project', () => {
      res = extractNamespaceData({ project: mockProject, group: mockGroup });

      expect(res).toBe(mockProject);
    });

    it('returns null if there is no group or project', () => {
      [{ namespace: mockPersonalNamespace }, {}, undefined].forEach((data) => {
        res = extractNamespaceData(data);

        expect(res).toBe(null);
      });
    });
  });
});
