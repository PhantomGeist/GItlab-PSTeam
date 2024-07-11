import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';

export const getProjectUsage = ({ id, name, numEvents }) => ({
  id,
  name,
  productAnalyticsEventsStored: numEvents !== undefined ? numEvents : 2345,
  webUrl: `/${name}`,
  avatarUrl: `/${name}.jpg`,
  __typename: 'Project',
});

export const getProjectsUsageDataResponse = (currentProjects, previousProjects) => ({
  previous: {
    id: convertToGraphQLId(TYPENAME_GROUP, 1),
    projects: {
      nodes: previousProjects || [
        getProjectUsage({
          id: convertToGraphQLId(TYPENAME_PROJECT, 1),
          name: 'some onboarded project',
          numEvents: 1234,
        }),
        getProjectUsage({
          id: convertToGraphQLId(TYPENAME_PROJECT, 2),
          name: 'not onboarded project',
          numEvents: null,
        }),
      ],
      __typename: 'ProjectConnection',
    },
    __typename: 'Group',
  },
  current: {
    id: convertToGraphQLId(TYPENAME_GROUP, 1),
    projects: {
      nodes: currentProjects || [
        getProjectUsage({
          id: convertToGraphQLId(TYPENAME_PROJECT, 1),
          name: 'some onboarded project',
          numEvents: 9876,
        }),
        getProjectUsage({
          id: convertToGraphQLId(TYPENAME_PROJECT, 2),
          name: 'not onboarded project',
          numEvents: null,
        }),
      ],
      __typename: 'ProjectConnection',
    },
    __typename: 'Group',
  },
});
