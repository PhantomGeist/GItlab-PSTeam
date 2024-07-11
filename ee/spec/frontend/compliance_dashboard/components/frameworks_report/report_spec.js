import { mount, shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  createComplianceFrameworksReportResponse,
  createComplianceFrameworksReportProjectsResponse,
} from 'ee_jest/compliance_dashboard/mock_data';

import ComplianceFrameworksReport from 'ee/compliance_dashboard/components/frameworks_report/report.vue';
import complianceFrameworks from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import complianceFrameworksProjects from 'ee/graphql_shared/queries/get_compliance_framework_associated_projects.query.graphql';

import { ROUTE_FRAMEWORKS } from 'ee/compliance_dashboard/constants';
import FrameworksTable from 'ee/compliance_dashboard/components/frameworks_report/frameworks_table.vue';

Vue.use(VueApollo);

describe('ComplianceFrameworksReport component', () => {
  let wrapper;
  let apolloProvider;
  const fullPath = 'group-path';
  let $router;

  const sentryError = new Error('GraphQL networkError');
  const frameworksResponse = createComplianceFrameworksReportResponse();
  const projectsResponse = createComplianceFrameworksReportProjectsResponse();
  const mockGraphQlLoading = jest.fn().mockResolvedValue(new Promise(() => {}));
  const mockFrameworksGraphQlSuccess = jest.fn().mockResolvedValue(frameworksResponse);
  const mockProjectsGraphQlSuccess = jest.fn().mockResolvedValue(projectsResponse);
  const mockGraphQlError = jest.fn().mockRejectedValue(sentryError);

  const findErrorMessage = () => wrapper.findComponent(GlAlert);
  const findFrameworksTable = () => wrapper.findComponent(FrameworksTable);

  function createMockApolloProvider(complianceFrameworksResolverMock, projectsResolverMock) {
    return createMockApollo([
      [complianceFrameworks, complianceFrameworksResolverMock],
      [complianceFrameworksProjects, projectsResolverMock],
    ]);
  }

  function createComponent(
    mountFn = shallowMount,
    props = {},
    complianceFrameworksResolverMock = mockGraphQlLoading,
    projectsResolverMock = mockGraphQlLoading,
    queryParams = {},
  ) {
    const currentQueryParams = { ...queryParams };
    $router = {
      push: jest.fn().mockImplementation(({ query }) => {
        Object.assign(currentQueryParams, query);
      }),
    };

    apolloProvider = createMockApolloProvider(
      complianceFrameworksResolverMock,
      projectsResolverMock,
    );

    wrapper = extendedWrapper(
      mountFn(ComplianceFrameworksReport, {
        apolloProvider,
        propsData: {
          groupPath: fullPath,
          ...props,
        },
        mocks: {
          $router,
          $route: {
            name: ROUTE_FRAMEWORKS,
          },
        },
      }),
    );
  }

  describe('default behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render an error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
    });
  });

  describe('when initializing', () => {
    beforeEach(() => {
      createComponent(mount, {}, mockGraphQlLoading);
    });

    it('renders the table loading icon', () => {
      expect(findFrameworksTable().exists()).toBe(true);
      expect(findFrameworksTable().props('isLoading')).toBe(true);
    });

    it('fetches the list of frameworks', () => {
      expect(mockGraphQlLoading).toHaveBeenCalledTimes(2);
      expect(mockGraphQlLoading).toHaveBeenCalledWith({
        fullPath,
      });
    });
  });

  describe('when the frameworks query fails', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
      createComponent(shallowMount, {}, mockGraphQlError, mockProjectsGraphQlSuccess);
    });

    it('renders the error message', async () => {
      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessage().text()).toBe(
        'Unable to load the compliance framework report. Refresh the page and try again.',
      );
      expect(Sentry.captureException.mock.calls[0][0].networkError).toBe(sentryError);
    });
  });

  describe('when the projects query fails', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
      createComponent(shallowMount, {}, mockFrameworksGraphQlSuccess, mockGraphQlError);
    });

    it('renders the error message', async () => {
      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessage().text()).toBe(
        'Unable to load the compliance framework report. Refresh the page and try again.',
      );
      expect(Sentry.captureException.mock.calls[0][0].networkError).toBe(sentryError);
    });
  });

  describe('when there are frameworks', () => {
    beforeEach(async () => {
      createComponent(mount, {}, mockFrameworksGraphQlSuccess, mockProjectsGraphQlSuccess);
      await waitForPromises();
    });

    it('passes results to the table', () => {
      expect(findFrameworksTable().props('frameworks')).toHaveLength(1);
      expect(findFrameworksTable().props('frameworks')[0]).toMatchObject({
        __typename: 'ComplianceFramework',
        color: '#3cb370',
        default: false,
        description: 'This is a framework 0',
        id: 'gid://gitlab/ComplianceManagement::Framework/0',
        name: 'Some framework 0',
        pipelineConfigurationFullPath: null,
      });
      expect(findFrameworksTable().props('projects')).toHaveLength(1);
      expect(findFrameworksTable().props('projects')[0]).toMatchObject({
        __typename: 'Project',
        id: 'gid://gitlab/Project/0',
        name: 'Gitlab Shell',
      });
    });
  });
});
