import { mount, shallowMount } from '@vue/test-utils';
import { GlTabs } from '@gitlab/ui';

import { __ } from '~/locale';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import ComplianceReportsApp from 'ee/compliance_dashboard/components/reports_app.vue';
import ReportHeader from 'ee/compliance_dashboard/components/shared/report_header.vue';
import MergeCommitsExportButton from 'ee/compliance_dashboard/components/violations_report/shared/merge_commits_export_button.vue';
import { stubComponent } from 'helpers/stub_component';
import { mockTracking } from 'helpers/tracking_helper';
import {
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
} from 'ee/compliance_dashboard/constants';

describe('ComplianceReportsApp component', () => {
  let wrapper;
  let trackingSpy;
  const defaultProps = {
    groupPath: 'group-path',
    mergeCommitsCsvExportPath: '/csv',
    frameworksCsvExportPath: '/framework_report.csv',
    violationsCsvExportPath: '/compliance_violation_reports.csv',
  };

  const findHeader = () => wrapper.findComponent(ReportHeader);
  const findMergeCommitsExportButton = () => wrapper.findComponent(MergeCommitsExportButton);
  const findViolationsExportButton = () => wrapper.findByTestId('violations-export');
  const findProjectsExportButton = () => wrapper.findByTestId('projects-export');
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findProjectsTab = () => wrapper.findByTestId('projects-tab-content');
  const findFrameworksTab = () => wrapper.findByTestId('frameworks-tab-content');
  const findViolationsTab = () => wrapper.findByTestId('violations-tab-content');
  const findStandardsAdherenceTab = () => wrapper.findByTestId('standards-adherence-tab-content');

  const createComponent = (props = {}, mountFn = shallowMount, mocks = {}, provide = {}) => {
    return extendedWrapper(
      mountFn(ComplianceReportsApp, {
        propsData: {
          ...defaultProps,
          ...props,
        },
        mocks: {
          $router: { push: jest.fn() },
          $route: {
            name: ROUTE_VIOLATIONS,
          },
          ...mocks,
        },
        stubs: {
          'router-view': stubComponent({}),
        },
        provide: {
          adherenceReportUiEnabled: false,
          complianceFrameworkReportUiEnabled: false,
          ...provide,
        },
      }),
    );
  };

  describe('adherence standards report', () => {
    beforeEach(() => {
      wrapper = createComponent(defaultProps, mount, {}, { adherenceReportUiEnabled: true });
    });

    it('renders the standards adherence report tab', () => {
      expect(findStandardsAdherenceTab().exists()).toBe(true);
    });
  });

  describe('violations report', () => {
    beforeEach(() => {
      wrapper = createComponent(defaultProps, mount);
    });

    it('renders the violations report tab', () => {
      expect(findViolationsTab().exists()).toBe(true);
    });

    it('passes the expected values to the header', () => {
      expect(findHeader().props()).toMatchObject({
        heading: __('Compliance center'),
        subheading: __(
          'Report and manage standards adherence, violations, and compliance frameworks for the group.',
        ),
        documentationPath: '/help/user/compliance/compliance_center/index.md',
      });
    });

    it('renders the merge commit export button', () => {
      expect(findMergeCommitsExportButton().exists()).toBe(true);
    });

    it('renders the violations export button', () => {
      expect(findViolationsExportButton().exists()).toBe(true);
    });

    it('does not render the projects export button', () => {
      expect(findProjectsExportButton().exists()).toBe(false);
    });

    it('does not render the merge commit export button when there is no CSV path', () => {
      wrapper = createComponent({ mergeCommitsCsvExportPath: null }, mount);
      findTabs().vm.$emit('input', 0);

      expect(findMergeCommitsExportButton().exists()).toBe(false);
    });

    it('does not render the violations export button when there is no CSV path', () => {
      wrapper = createComponent({ violationsCsvExportPath: null }, mount);
      findTabs().vm.$emit('input', 0);

      expect(findViolationsExportButton().exists()).toBe(false);
    });
  });

  describe('projects report', () => {
    beforeEach(() => {
      wrapper = createComponent(
        defaultProps,
        mount,
        {
          $route: {
            name: ROUTE_PROJECTS,
          },
        },
        { complianceFrameworkReportUiEnabled: false },
      );
    });

    it('renders the projects report tab', () => {
      expect(findProjectsTab().exists()).toBe(true);
    });

    it('does not render the frameworks report tab', () => {
      expect(findFrameworksTab().exists()).toBe(false);
    });

    it('passes the expected values to the header', () => {
      expect(findHeader().props()).toMatchObject({
        heading: __('Compliance center'),
        subheading: __(
          'Report and manage standards adherence, violations, and compliance frameworks for the group.',
        ),
        documentationPath: '/help/user/compliance/compliance_center/index.md',
      });
    });

    it('does not render the merge commit export button', () => {
      expect(findMergeCommitsExportButton().exists()).toBe(false);
    });

    it('renders the projects export button', () => {
      expect(findProjectsExportButton().exists()).toBe(true);
    });

    it('does not render the projects export button when there is no CSV path', () => {
      wrapper = createComponent({ frameworksCsvExportPath: null }, mount, {
        $route: {
          name: ROUTE_FRAMEWORKS,
        },
      });

      expect(findProjectsExportButton().exists()).toBe(false);
    });
  });

  describe('frameworks report', () => {
    beforeEach(() => {
      wrapper = createComponent(
        defaultProps,
        mount,
        {
          $route: {
            name: ROUTE_PROJECTS,
          },
        },
        { complianceFrameworkReportUiEnabled: true },
      );
    });

    it('renders the projects tab', () => {
      expect(findProjectsTab().exists()).toBe(true);
    });

    it('renders the frameworks report tab', () => {
      expect(findFrameworksTab().exists()).toBe(true);
    });
  });

  describe('tracking', () => {
    beforeEach(() => {
      wrapper = createComponent(
        defaultProps,
        mount,
        {
          $route: {
            name: ROUTE_VIOLATIONS,
          },
        },
        {
          adherenceReportUiEnabled: true,
          complianceFrameworkReportUiEnabled: true,
        },
      );
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    });

    it('tracks clicks on framework tab', () => {
      findFrameworksTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'frameworks',
      });
    });
    it('tracks clicks on projects tab', () => {
      findProjectsTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'projects',
      });
    });
    it('tracks clicks on adherence tab', () => {
      findStandardsAdherenceTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'standards_adherence',
      });
    });
    it('tracks clicks on violations tab', () => {
      // Can't navigate to a page we are already on so use a different tab to start with
      wrapper = createComponent(defaultProps, mount, {
        $route: {
          name: ROUTE_FRAMEWORKS,
        },
      });
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      findViolationsTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'violations',
      });
    });
  });
});
