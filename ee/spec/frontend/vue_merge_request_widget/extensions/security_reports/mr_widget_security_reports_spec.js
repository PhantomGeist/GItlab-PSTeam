import { GlBadge } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import { createWrapper } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import MRSecurityWidget from 'ee/vue_merge_request_widget/extensions/security_reports/mr_widget_security_reports.vue';
import FindingModal from 'ee/vue_shared/security_reports/components/modal.vue';
import VulnerabilityFindingModal from 'ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue';
import SummaryText from 'ee/vue_merge_request_widget/extensions/security_reports/summary_text.vue';
import findingQuery from 'ee/security_dashboard/graphql/queries/mr_widget_finding.query.graphql';
import dismissFindingMutation from 'ee/security_dashboard/graphql/mutations/dismiss_finding.mutation.graphql';
import revertFindingToDetectedMutation from 'ee/security_dashboard/graphql/mutations/revert_finding_to_detected.mutation.graphql';
import createIssueMutation from 'ee/security_dashboard/graphql/mutations/finding_create_issue.mutation.graphql';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import Widget from '~/vue_merge_request_widget/components/widget/widget.vue';
import toast from '~/vue_shared/plugins/global_toast';
import download from '~/lib/utils/downloader';
import MrWidgetRow from '~/vue_merge_request_widget/components/widget/widget_content_row.vue';
import * as urlUtils from '~/lib/utils/url_utility';
import { BV_HIDE_MODAL } from '~/lib/utils/constants';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_BAD_REQUEST, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import { findingMockData, findingQueryMockData } from './mock_data';

jest.mock('~/vue_shared/components/user_callout_dismisser.vue', () => ({ render: () => {} }));
jest.mock('~/vue_shared/plugins/global_toast');
jest.mock('~/lib/utils/downloader');

Vue.use(VueApollo);

const DISMISSAL_RESPONSE = jest.fn().mockResolvedValue({
  data: {
    securityFindingDismiss: {
      errors: [],
      securityFinding: {
        vulnerability: {
          id: 1,
          stateTransitions: {
            nodes: {
              author: null,
              comment: 'comment',
              createdAt: '',
              toState: 'DISMISSED',
            },
          },
        },
      },
    },
  },
});

describe('MR Widget Security Reports', () => {
  let wrapper;
  let mockAxios;

  const securityConfigurationPath = '/help/user/application_security/index.md';
  const sourceProjectFullPath = 'namespace/project';
  const testModalId = 'modal-mrwidget-security-issue';

  const sastHelp = '/help/user/application_security/sast/index';
  const dastHelp = '/help/user/application_security/dast/index';
  const coverageFuzzingHelp = '/help/user/application_security/coverage-fuzzing/index';
  const secretDetectionHelp = '/help/user/application_security/secret-detection/index';
  const apiFuzzingHelp = '/help/user/application_security/api-fuzzing/index';
  const dependencyScanningHelp = '/help/user/application_security/api-fuzzing/index';
  const containerScanningHelp = '/help/user/application_security/container-scanning/index';
  const createVulnerabilityFeedbackIssuePath = '/create/vulnerability/feedback/issue/path';
  const createVulnerabilityFeedbackDismissalPath = '/dismiss/finding/feedback/path';
  const createVulnerabilityFeedbackMergeRequestPath = '/create/merge/request/path';

  const reportEndpoints = {
    sastComparisonPathV2: '/my/sast/endpoint',
    dastComparisonPathV2: '/my/dast/endpoint',
    dependencyScanningComparisonPathV2: '/my/dependency-scanning/endpoint',
    coverageFuzzingComparisonPathV2: '/my/coverage-fuzzing/endpoint',
    apiFuzzingComparisonPathV2: '/my/api-fuzzing/endpoint',
    secretDetectionComparisonPathV2: '/my/secret-detection/endpoint',
    containerScanningComparisonPathV2: '/my/container-scanning/endpoint',
  };

  const createComponent = ({
    propsData,
    mountFn = shallowMountExtended,
    findingHandler = [findingQuery, findingQueryMockData()],
    additionalHandlers = [],
    enableStandaloneModal = true,
  } = {}) => {
    wrapper = mountFn(MRSecurityWidget, {
      apolloProvider: createMockApollo([findingHandler, ...additionalHandlers]),
      provide: {
        glFeatures: {
          standaloneFindingModalMergeRequestWidget: enableStandaloneModal,
        },
      },
      propsData: {
        ...propsData,
        mr: {
          pipeline: {
            path: '/path/to/pipeline',
          },
          enabledReports: {
            sast: true,
            dast: true,
            dependencyScanning: true,
            containerScanning: true,
            coverageFuzzing: true,
            apiFuzzing: true,
            secretDetection: true,
          },
          ...propsData?.mr,
          ...reportEndpoints,
          createVulnerabilityFeedbackMergeRequestPath,
          securityConfigurationPath,
          sourceProjectFullPath,
          sastHelp,
          dastHelp,
          containerScanningHelp,
          dependencyScanningHelp,
          coverageFuzzingHelp,
          secretDetectionHelp,
          apiFuzzingHelp,
        },
      },
      stubs: {
        MrWidgetRow,
      },
    });
  };

  const createComponentAndExpandWidget = async ({
    mockDataFn,
    mockDataProps,
    mrProps = {},
    additionalHandlers,
    enableStandaloneModal,
  }) => {
    mockDataFn(mockDataProps);
    createComponent({
      mountFn: mountExtended,
      additionalHandlers,
      propsData: {
        mr: mrProps,
      },
      enableStandaloneModal,
    });

    await waitForPromises();

    // Click on the toggle button to expand data
    wrapper.findByRole('button', { name: 'Show details' }).trigger('click');
    await nextTick();

    // Second next tick is for the dynamic scroller
    await nextTick();
  };

  const findWidget = () => wrapper.findComponent(Widget);
  const findWidgetRow = (reportType) => wrapper.findByTestId(`report-${reportType}`);
  const findSummaryText = () => wrapper.findComponent(SummaryText);
  const findReportSummaryText = (at) => wrapper.findAllComponents(SummaryText).at(at);
  const findSummaryHighlights = () => wrapper.findComponent(SummaryHighlights);
  const findDismissedBadge = () => wrapper.findComponent(GlBadge);
  const findModal = () => wrapper.findComponent(FindingModal);
  const findStandaloneModal = () => wrapper.findComponent(VulnerabilityFindingModal);
  const findDynamicScroller = () => wrapper.findByTestId('dynamic-content-scroller');

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('with active pipeline', () => {
    beforeEach(() => {
      createComponent({ propsData: { mr: { isPipelineActive: true } } });
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with no enabled reports', () => {
    beforeEach(() => {
      createComponent({ propsData: { mr: { isPipelineActive: false, enabledReports: {} } } });
    });

    it('should not mount the widget component', () => {
      expect(findWidget().exists()).toBe(false);
    });
  });

  describe('with empty MR data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should mount the widget component', () => {
      expect(findWidget().props()).toMatchObject({
        statusIconName: 'success',
        widgetName: 'WidgetSecurityReports',
        errorText: 'Security reports failed loading results',
        loadingText: 'Loading',
        fetchCollapsedData: expect.any(Function),
        multiPolling: true,
      });
    });

    it('handles loading state', async () => {
      expect(findSummaryText().props()).toMatchObject({ isLoading: true });
      findWidget().vm.$emit('is-loading', false);
      await nextTick();
      expect(findSummaryText().props()).toMatchObject({ isLoading: false });
    });

    it('does not display the summary highlights component', () => {
      expect(findSummaryHighlights().exists()).toBe(false);
    });

    it('should not be collapsible', () => {
      expect(findWidget().props('isCollapsible')).toBe(false);
    });
  });

  describe('with MR data', () => {
    const mockWithData = ({ findings } = {}) => {
      mockAxios.onGet(reportEndpoints.sastComparisonPathV2).replyOnce(
        HTTP_STATUS_OK,
        findings?.sast || {
          added: [
            {
              uuid: '1',
              severity: 'critical',
              name: 'Password leak',
              state: 'dismissed',
            },
            { uuid: '2', severity: 'high', name: 'XSS vulnerability' },
          ],
          fixed: [
            { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
            { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
          ],
        },
      );

      mockAxios.onGet(reportEndpoints.dastComparisonPathV2).replyOnce(
        HTTP_STATUS_OK,
        findings?.dast || {
          added: [
            { uuid: '5', severity: 'low', name: 'SQL Injection' },
            { uuid: '3', severity: 'unknown', name: 'Weak password' },
          ],
        },
      );

      [
        reportEndpoints.dependencyScanningComparisonPathV2,
        reportEndpoints.coverageFuzzingComparisonPathV2,
        reportEndpoints.apiFuzzingComparisonPathV2,
        reportEndpoints.secretDetectionComparisonPathV2,
        reportEndpoints.containerScanningComparisonPathV2,
      ].forEach((path) => {
        mockAxios.onGet(path).replyOnce(HTTP_STATUS_OK, {
          added: [],
        });
      });
    };

    const createComponentWithData = async () => {
      mockWithData();

      createComponent({
        mountFn: mountExtended,
      });

      await waitForPromises();
    };

    it('should make a call only for enabled reports', async () => {
      mockWithData();

      createComponent({
        mountFn: mountExtended,
        propsData: {
          mr: {
            enabledReports: {
              sast: true,
              dast: true,
            },
          },
        },
      });

      await waitForPromises();

      expect(mockAxios.history.get).toHaveLength(2);
    });

    it('should display the full report button', async () => {
      await createComponent();

      expect(findWidget().props('actionButtons')).toEqual([
        {
          href: '/path/to/pipeline/security',
          text: 'Full report',
          trackFullReportClicked: true,
        },
      ]);
    });

    it('should display the dismissed badge', async () => {
      await createComponentAndExpandWidget({ mockDataFn: mockWithData });
      expect(findDismissedBadge().text()).toBe('Dismissed');
    });

    it('should mount the widget component', async () => {
      await createComponentWithData();

      expect(findWidget().props()).toMatchObject({
        statusIconName: 'warning',
        widgetName: 'WidgetSecurityReports',
        errorText: 'Security reports failed loading results',
        loadingText: 'Loading',
        fetchCollapsedData: wrapper.vm.fetchCollapsedData,
        multiPolling: true,
      });
    });

    it('computes the total number of new potential vulnerabilities correctly', async () => {
      await createComponentWithData();

      expect(findSummaryText().props()).toMatchObject({ totalNewVulnerabilities: 4 });
      expect(findSummaryHighlights().props()).toMatchObject({
        highlights: { critical: 1, high: 1, other: 2 },
      });
    });

    it('tells the widget to be collapsible only if there is data', async () => {
      mockWithData();

      createComponent({
        mountFn: mountExtended,
      });

      expect(findWidget().props('isCollapsible')).toBe(false);
      await waitForPromises();
      expect(findWidget().props('isCollapsible')).toBe(true);
    });

    it('displays detailed data when expanded', async () => {
      await createComponentAndExpandWidget({ mockDataFn: mockWithData });

      expect(wrapper.findByText(/Weak password/).exists()).toBe(true);
      expect(wrapper.findByText(/Password leak/).exists()).toBe(true);
      expect(wrapper.findByTestId('SAST-report-header').text()).toBe(
        'SAST detected 2 new potential vulnerabilities',
      );
    });

    it('contains new and fixed findings in the dynamic scroller', async () => {
      await createComponentAndExpandWidget({ mockDataFn: mockWithData });

      expect(findDynamicScroller().props('items')).toEqual([
        // New findings
        {
          uuid: '1',
          severity: 'critical',
          name: 'Password leak',
          state: 'dismissed',
        },
        { uuid: '2', severity: 'high', name: 'XSS vulnerability' },
        // Fixed findings
        { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
        { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
      ]);

      expect(wrapper.findByTestId('new-findings-title').text()).toBe('New');
      expect(wrapper.findByTestId('fixed-findings-title').text()).toBe('Fixed');
    });

    it('contains only fixed findings in the dynamic scroller', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {
              fixed: [
                { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
                { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
              ],
            },
            dast: {},
          },
        },
      });

      expect(findDynamicScroller().props('items')).toEqual([
        { uuid: '14abc', severity: 'high', name: 'SQL vulnerability' },
        { uuid: 'bc41e', severity: 'high', name: 'SQL vulnerability 2' },
      ]);

      expect(wrapper.findByTestId('new-findings-title').exists()).toBe(false);
      expect(wrapper.findByTestId('fixed-findings-title').text()).toBe('Fixed');
    });

    it('contains only added findings in the dynamic scroller', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {},
          },
        },
      });

      expect(findDynamicScroller().props('items')).toEqual([
        { uuid: '5', severity: 'low', name: 'SQL Injection' },
        { uuid: '3', severity: 'unknown', name: 'Weak password' },
      ]);

      expect(wrapper.findByTestId('new-findings-title').text()).toBe('New');
      expect(wrapper.findByTestId('fixed-findings-title').exists()).toBe(false);
    });

    it('tells summary-text to display a ui hint when there are 25 findings in a single report', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {
              added: [...Array(25)].map((i) => ({
                uuid: `${i}4abc`,
                severity: 'high',
                name: 'SQL vulnerability',
              })),
            },
            dast: {
              added: [...Array(10)].map((i) => ({
                uuid: `${i}3abc`,
                severity: 'critical',
                name: 'Dast vulnerability',
              })),
            },
          },
        },
      });

      // header
      expect(findSummaryText().props('showAtLeastHint')).toBe(true);
      // sast and dast reports. These are always true because individual reports
      // will not return more than 25 records.
      expect(findReportSummaryText(1).props('showAtLeastHint')).toBe(true);
      expect(findReportSummaryText(2).props('showAtLeastHint')).toBe(true);
    });

    it('tells summary-text NOT to display a ui hint when there are less 25 findings', async () => {
      await createComponentAndExpandWidget({
        mockDataFn: mockWithData,
        mockDataProps: {
          findings: {
            sast: {
              added: [...Array(24)].map((i) => ({
                uuid: `${i}4abc`,
                severity: 'high',
                name: 'SQL vulnerability',
              })),
            },
            dast: {
              added: [...Array(10)].map((i) => ({
                uuid: `${i}3abc`,
                severity: 'critical',
                name: 'Dast vulnerability',
              })),
            },
          },
        },
      });

      // header
      expect(findSummaryText().props('showAtLeastHint')).toBe(false);
      // sast and dast reports. These are always true because individual reports
      // will not return more than 25 records.
      expect(findReportSummaryText(1).props('showAtLeastHint')).toBe(true);
      expect(findReportSummaryText(2).props('showAtLeastHint')).toBe(true);
    });
  });

  describe('error states', () => {
    const mockWithData = () => {
      mockAxios.onGet(reportEndpoints.sastComparisonPathV2).replyOnce(HTTP_STATUS_BAD_REQUEST);

      mockAxios.onGet(reportEndpoints.dastComparisonPathV2).replyOnce(HTTP_STATUS_OK, {
        added: [
          { uuid: 5, severity: 'low', name: 'SQL Injection' },
          { uuid: 3, severity: 'unknown', name: 'Weak password' },
        ],
      });

      [
        reportEndpoints.dependencyScanningComparisonPathV2,
        reportEndpoints.coverageFuzzingComparisonPathV2,
        reportEndpoints.apiFuzzingComparisonPathV2,
        reportEndpoints.secretDetectionComparisonPathV2,
        reportEndpoints.containerScanningComparisonPathV2,
      ].forEach((path) => {
        mockAxios.onGet(path).replyOnce(HTTP_STATUS_OK, {
          added: [],
        });
      });
    };

    it('displays an error message for the individual level report', async () => {
      await createComponentAndExpandWidget({ mockDataFn: mockWithData });

      expect(wrapper.findByText('SAST: Loading resulted in an error').exists()).toBe(true);
    });
  });

  describe('help popovers', () => {
    const mockWithData = () => {
      Object.keys(reportEndpoints).forEach((key, i) => {
        mockAxios.onGet(reportEndpoints[key]).replyOnce(HTTP_STATUS_OK, {
          added: [{ uuid: i, severity: 'critical', name: 'Password leak' }],
        });
      });
    };

    it.each`
      reportType               | reportTitle                                      | helpPath
      ${'SAST'}                | ${'Static Application Security Testing (SAST)'}  | ${sastHelp}
      ${'DAST'}                | ${'Dynamic Application Security Testing (DAST)'} | ${dastHelp}
      ${'DEPENDENCY_SCANNING'} | ${'Dependency scanning'}                         | ${dependencyScanningHelp}
      ${'COVERAGE_FUZZING'}    | ${'Coverage fuzzing'}                            | ${coverageFuzzingHelp}
      ${'API_FUZZING'}         | ${'API fuzzing'}                                 | ${apiFuzzingHelp}
      ${'SECRET_DETECTION'}    | ${'Secret detection'}                            | ${secretDetectionHelp}
      ${'CONTAINER_SCANNING'}  | ${'Container scanning'}                          | ${containerScanningHelp}
    `(
      'shows the correct help popover for $reportType',
      async ({ reportType, reportTitle, helpPath }) => {
        await createComponentAndExpandWidget({ mockDataFn: mockWithData });

        expect(findWidgetRow(reportType).props('helpPopover')).toMatchObject({
          options: { title: reportTitle },
          content: { learnMorePath: helpPath },
        });
      },
    );
  });

  describe('modal', () => {
    const mockWithData = (props) => {
      Object.keys(reportEndpoints).forEach((key, i) => {
        mockAxios.onGet(reportEndpoints[key]).replyOnce(HTTP_STATUS_OK, {
          added: [
            {
              uuid: i.toString(),
              severity: 'critical',
              name: 'Password leak',
              found_by_pipeline: {
                iid: 1,
              },
              project: {
                id: 278964,
                name: 'GitLab',
                full_path: '/gitlab-org/gitlab',
                full_name: 'GitLab.org / GitLab',
              },
              ...props,
            },
          ],
        });
      });
    };

    const createComponentExpandWidgetAndOpenModal = async ({
      mockDataFn = mockWithData,
      mockDataProps,
      mrProps,
      additionalHandlers,
      enableStandaloneModal = true,
    } = {}) => {
      await createComponentAndExpandWidget({
        mockDataFn,
        mockDataProps,
        mrProps,
        additionalHandlers,
        enableStandaloneModal,
      });

      // Click on the vulnerability name
      wrapper.findAllByText('Password leak').at(0).trigger('click');

      if (enableStandaloneModal) {
        // We need to wait for the import and the mounting of vulnerability_finding_modal.vue
        // because it's dynamically imported.
        await import('ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue');
        await nextTick();
      }
    };

    describe('`standalone_finding_modal_merge_request_widget` enabled', () => {
      const mockWithDataOneFinding = (state = 'dismissed') => {
        mockAxios.onGet(reportEndpoints.sastComparisonPathV2).replyOnce(HTTP_STATUS_OK, {
          added: [
            {
              uuid: '1',
              severity: 'critical',
              name: 'Password leak',
              state,
              found_by_pipeline: {
                iid: 1,
              },
              project: {
                id: 278964,
                name: 'GitLab',
                full_path: '/gitlab-org/gitlab',
                full_name: 'GitLab.org / GitLab',
              },
            },
          ],
          fixed: [],
        });

        [
          reportEndpoints.dastComparisonPathV2,
          reportEndpoints.dependencyScanningComparisonPathV2,
          reportEndpoints.coverageFuzzingComparisonPathV2,
          reportEndpoints.apiFuzzingComparisonPathV2,
          reportEndpoints.secretDetectionComparisonPathV2,
          reportEndpoints.containerScanningComparisonPathV2,
        ].forEach((path) => {
          mockAxios.onGet(path).replyOnce(HTTP_STATUS_OK, {
            added: [],
          });
        });
      };

      it('does not display the modal until the finding is clicked', async () => {
        await createComponentAndExpandWidget({
          mockDataFn: mockWithData,
        });

        expect(findStandaloneModal().exists()).toBe(false);
      });

      it('clears modal data when the modal is closed', async () => {
        await createComponentExpandWidgetAndOpenModal();

        expect(findStandaloneModal().props('modal')).not.toBe(null);

        findStandaloneModal().vm.$emit('hidden');
        await nextTick();

        expect(findStandaloneModal().exists()).toBe(false);
      });

      it('renders the modal when the finding is clicked', async () => {
        const targetProjectFullPath = 'root/security-reports-v2';
        await createComponentExpandWidgetAndOpenModal({
          mrProps: { targetProjectFullPath },
        });

        const modal = findStandaloneModal();

        expect(modal.props()).toMatchObject({
          findingUuid: '0',
          pipelineIid: 1,
          projectFullPath: targetProjectFullPath,
        });
      });

      it('renders the dismissed badge when `dismissed` is emitted', async () => {
        await createComponentExpandWidgetAndOpenModal({
          mockDataFn: mockWithDataOneFinding,
          mockDataProps: { state: 'detected' },
        });

        expect(findDismissedBadge().exists()).toBe(false);

        findStandaloneModal().vm.$emit('dismissed');
        await nextTick();

        expect(findDismissedBadge().exists()).toBe(true);
      });

      it('does not render the dismissed badge when `detected` is emitted', async () => {
        await createComponentExpandWidgetAndOpenModal({ mockDataFn: mockWithDataOneFinding });

        expect(findDismissedBadge().exists()).toBe(true);

        findStandaloneModal().vm.$emit('detected');
        await nextTick();

        expect(findDismissedBadge().exists()).toBe(false);
      });
    });

    describe('`standalone_finding_modal_merge_request_widget` disabled', () => {
      it('does not display the modal until the finding is clicked', async () => {
        await createComponentAndExpandWidget({
          mockDataFn: mockWithData,
          enableStandaloneModal: false,
        });

        expect(findModal().exists()).toBe(false);
      });

      it('clears modal data when the modal is closed', async () => {
        await createComponentExpandWidgetAndOpenModal({ enableStandaloneModal: false });

        expect(findModal().props('modal')).not.toBe(null);

        findModal().vm.$emit('hidden');
        await nextTick();

        expect(findModal().exists()).toBe(false);
      });

      it('renders the modal when the finding is clicked', async () => {
        await createComponentExpandWidgetAndOpenModal({ enableStandaloneModal: false });

        const modal = findModal();

        expect(modal.props('canCreateIssue')).toBe(false);
        expect(modal.props('isDismissingVulnerability')).toBe(false);
        expect(modal.props('isLoadingAdditionalInfo')).toBe(true);

        await waitForPromises();

        expect(modal.props('isLoadingAdditionalInfo')).toBe(false);

        const { mergeRequest, issueLinks, vulnerability } = findingMockData;
        const { issue } = issueLinks.nodes[0];

        expect(modal.props('modal')).toMatchObject({
          title: 'Password leak',
          error: null,
          isShowingDeleteButtons: false,
          vulnerability: {
            uuid: '0',
            severity: 'critical',
            name: 'Password leak',
            state_transitions: vulnerability.stateTransitions.nodes.map(
              convertObjectPropsToSnakeCase,
            ),
            merge_request_links: [
              {
                author: mergeRequest.author,
                merge_request_path: mergeRequest.webUrl,
                created_at: mergeRequest.createdAt,
                merge_request_iid: mergeRequest.iid,
              },
            ],
            issue_links: [
              {
                author: issue.author,
                created_at: issue.createdAt,
                issue_url: issue.webUrl,
                issue_iid: issue.iid,
                link_type: 'created',
              },
            ],
          },
        });
      });

      it('downloads a patch when the downloadPatch event is emitted', async () => {
        await createComponentExpandWidgetAndOpenModal({
          mockDataProps: {
            remediations: [{ diff: 'some-diff' }],
          },
          enableStandaloneModal: false,
        });

        findModal().vm.$emit('downloadPatch');

        expect(download).toHaveBeenCalledWith({
          fileData: 'some-diff',
          fileName: 'remediation.patch',
        });
      });

      describe('merge request creation', () => {
        it('handles merge request creation - success', async () => {
          const mergeRequestPath = '/merge/request/1';

          mockAxios.onPost(createVulnerabilityFeedbackMergeRequestPath).replyOnce(HTTP_STATUS_OK, {
            merge_request_links: [{ merge_request_path: mergeRequestPath }],
          });

          await createComponentExpandWidgetAndOpenModal({
            mrProps: {
              createVulnerabilityFeedbackDismissalPath,
            },
            enableStandaloneModal: false,
          });

          const spy = jest.spyOn(urlUtils, 'visitUrl');

          expect(findModal().props('isCreatingMergeRequest')).toBe(false);

          findModal().vm.$emit('createMergeRequest');

          await nextTick();

          expect(findModal().props('isCreatingMergeRequest')).toBe(true);

          await waitForPromises();

          expect(spy).toHaveBeenCalledWith(mergeRequestPath);
        });

        it('handles merge request creation - error', async () => {
          mockAxios
            .onPost(createVulnerabilityFeedbackMergeRequestPath)
            .replyOnce(HTTP_STATUS_BAD_REQUEST);

          await createComponentExpandWidgetAndOpenModal({
            mrProps: {
              createVulnerabilityFeedbackDismissalPath,
            },
            enableStandaloneModal: false,
          });

          findModal().vm.$emit('createMergeRequest');

          await waitForPromises();

          expect(findModal().props('modal').error).toBe(
            'There was an error creating the merge request. Please try again.',
          );
        });
      });

      describe('issue creation', () => {
        it('can create issue when createVulnerabilityFeedbackIssuePath is provided', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mrProps: {
              createVulnerabilityFeedbackIssuePath,
            },
            enableStandaloneModal: false,
          });

          expect(findModal().props('canCreateIssue')).toBe(true);
        });

        it('can create issue when user can create a jira issue', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mockDataProps: {
              create_jira_issue_url: 'create/jira/issue/url',
            },
            enableStandaloneModal: false,
          });

          expect(findModal().props('canCreateIssue')).toBe(true);
        });

        it('handles issue creation - success', async () => {
          const webUrl = 'https://gitlab.com/issue/1';

          await createComponentExpandWidgetAndOpenModal({
            mrProps: {
              createVulnerabilityFeedbackIssuePath,
            },
            enableStandaloneModal: false,
            additionalHandlers: [
              [
                createIssueMutation,
                jest.fn().mockResolvedValue({
                  data: {
                    securityFindingCreateIssue: {
                      issue: {
                        id: '1',
                        webUrl,
                      },
                      errors: [],
                    },
                  },
                }),
              ],
            ],
          });

          const spy = jest.spyOn(urlUtils, 'visitUrl');

          findModal().vm.$emit('createNewIssue');

          await waitForPromises();

          expect(spy).toHaveBeenCalledWith(webUrl);
        });

        it('handles issue creation - error', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mrProps: {
              createVulnerabilityFeedbackIssuePath,
            },
            enableStandaloneModal: false,
            additionalHandlers: [[createIssueMutation, jest.fn().mockRejectedValue()]],
          });

          findModal().vm.$emit('createNewIssue');

          await waitForPromises();

          expect(findModal().props('modal').error).toBe(
            'There was an error creating the issue. Please try again.',
          );
        });
      });

      describe('dismissing finding', () => {
        it('can dismiss finding when createVulnerabilityFeedbackDismissalPath is provided', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mrProps: {
              createVulnerabilityFeedbackDismissalPath,
            },
            enableStandaloneModal: false,
          });

          expect(findModal().props('canDismissVulnerability')).toBe(true);
        });

        it('handles dismissing finding - success', async () => {
          await createComponentExpandWidgetAndOpenModal({
            enableStandaloneModal: false,
            additionalHandlers: [[dismissFindingMutation, DISMISSAL_RESPONSE]],
          });

          const rootWrapper = createWrapper(wrapper.vm.$root);

          expect(findDismissedBadge().exists()).toBe(false);
          expect(rootWrapper.emitted(BV_HIDE_MODAL)).toBeUndefined();

          findModal().vm.$emit('dismissVulnerability');

          await waitForPromises();

          expect(toast).toHaveBeenCalledWith("Dismissed 'Password leak'");
          expect(rootWrapper.emitted(BV_HIDE_MODAL)[0]).toContain(testModalId);

          // There should be a finding with the dismissed badge now
          expect(findDismissedBadge().text()).toBe('Dismissed');
        });

        it('handles dismissing finding - error', async () => {
          await createComponentExpandWidgetAndOpenModal({
            enableStandaloneModal: false,
            additionalHandlers: [[dismissFindingMutation, jest.fn().mockRejectedValue()]],
          });

          findModal().vm.$emit('dismissVulnerability');

          await waitForPromises();

          expect(findModal().props('modal').error).toBe(
            'There was an error dismissing the vulnerability. Please try again.',
          );

          expect(findDismissedBadge().exists()).toBe(false);
        });
      });

      describe('dismissal comment', () => {
        let mockDataProps;

        beforeEach(() => {
          mockDataProps = {
            state: 'dismissed',
            state_transitions: [
              {
                author: {},
                to_state: 'DISMISSED',
              },
            ],
            dismissal_feedback: {
              author: {},
              project_id: 20,
              id: 15,
            },
          };
        });

        it.each`
          event                                  | booleanValue
          ${'openDismissalCommentBox'}           | ${true}
          ${'closeDismissalCommentBox'}          | ${false}
          ${'editVulnerabilityDismissalComment'} | ${true}
        `('handles opening dismissal comment for event $event', async ({ event, booleanValue }) => {
          await createComponentExpandWidgetAndOpenModal({
            mockDataProps,
            enableStandaloneModal: false,
          });

          expect(findModal().props('modal').isCommentingOnDismissal).toBeUndefined();

          findModal().vm.$emit(event);

          await waitForPromises();

          expect(findModal().props('modal').isCommentingOnDismissal).toBe(booleanValue);
        });

        it('adds the dismissal comment - success', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mockDataProps,
            enableStandaloneModal: false,
            additionalHandlers: [[dismissFindingMutation, DISMISSAL_RESPONSE]],
          });
          const rootWrapper = createWrapper(wrapper.vm.$root);
          findModal().vm.$emit('addDismissalComment', 'Edited comment');

          await waitForPromises();

          expect(toast).toHaveBeenCalledWith("Comment added to 'Password leak'");
          expect(rootWrapper.emitted(BV_HIDE_MODAL)[0]).toContain(testModalId);
        });

        it('edits the dismissal comment - success', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mockDataProps,
            enableStandaloneModal: false,
            additionalHandlers: [[dismissFindingMutation, DISMISSAL_RESPONSE]],
          });
          const rootWrapper = createWrapper(wrapper.vm.$root);
          await waitForPromises();

          findModal().vm.$emit('addDismissalComment', 'Edited comment');

          await waitForPromises();

          expect(toast).toHaveBeenCalledWith("Comment edited on 'Password leak'");
          expect(rootWrapper.emitted(BV_HIDE_MODAL)[0]).toContain(testModalId);
        });

        it('adds the dismissal comment - error', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mockDataProps,
            enableStandaloneModal: false,
            additionalHandlers: [[dismissFindingMutation, jest.fn().mockRejectedValue()]],
          });

          findModal().vm.$emit('addDismissalComment', 'Edited comment');

          await waitForPromises();

          expect(toast).not.toHaveBeenCalled();
          expect(findModal().props('modal').error).toBe('There was an error adding the comment.');
        });

        it('deletes the dismissal comment - success', async () => {
          mockDataProps.dismissal_feedback.comment_details = {
            comment: 'Existing comment',
            comment_author: { id: 15 },
          };

          await createComponentExpandWidgetAndOpenModal({
            mockDataProps,
            enableStandaloneModal: false,
            additionalHandlers: [[dismissFindingMutation, DISMISSAL_RESPONSE]],
          });
          const rootWrapper = createWrapper(wrapper.vm.$root);

          expect(findModal().props('modal').isShowingDeleteButtons).toBe(false);

          // This displays the `Delete` button
          findModal().vm.$emit('showDismissalDeleteButtons');
          await nextTick();

          expect(findModal().props('modal').isShowingDeleteButtons).toBe(true);

          // This triggers the actual delete call
          findModal().vm.$emit('deleteDismissalComment');
          await nextTick();

          await waitForPromises();

          expect(toast).toHaveBeenCalledWith("Comment deleted on 'Password leak'");
          expect(rootWrapper.emitted(BV_HIDE_MODAL)[0]).toContain(testModalId);
        });

        it('deletes the dismissal comment - error', async () => {
          mockDataProps.dismissal_feedback.comment_details = {
            comment: 'Existing comment',
            comment_author: { id: 15 },
          };

          await createComponentExpandWidgetAndOpenModal({
            mockDataProps,
            enableStandaloneModal: false,
            additionalHandlers: [[dismissFindingMutation, jest.fn().mockRejectedValue()]],
          });

          expect(findModal().props('modal').isShowingDeleteButtons).toBe(false);

          // This displays the `Delete` button
          findModal().vm.$emit('showDismissalDeleteButtons');
          await nextTick();

          expect(findModal().props('modal').isShowingDeleteButtons).toBe(true);

          // This triggers the actual delete call
          findModal().vm.$emit('deleteDismissalComment');
          await nextTick();

          await waitForPromises();

          expect(toast).not.toHaveBeenCalled();
          expect(findModal().props('modal').error).toBe('There was an error deleting the comment.');
        });
      });

      describe('undo dismissing finding', () => {
        let mockDataProps;

        beforeEach(() => {
          mockDataProps = {
            state: 'dismissed',
            dismissal_feedback: {
              author: {},
            },
          };
        });

        it('handles undoing dismissing a finding - success', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mockDataProps,
            enableStandaloneModal: false,
            additionalHandlers: [
              [
                revertFindingToDetectedMutation,
                jest.fn().mockResolvedValue({
                  data: {
                    securityFindingRevertToDetected: {
                      errors: [],
                      securityFinding: {
                        vulnerability: {
                          id: 1,
                          stateTransitions: {
                            nodes: {
                              author: null,
                              comment: 'comment',
                              createdAt: '',
                              toState: 'DETECTED',
                            },
                          },
                        },
                      },
                    },
                  },
                }),
              ],
            ],
          });
          const rootWrapper = createWrapper(wrapper.vm.$root);

          findModal().vm.$emit('revertDismissVulnerability');

          await waitForPromises();

          expect(rootWrapper.emitted(BV_HIDE_MODAL)[0]).toContain(testModalId);

          // The dismissal_feedback object should be set back to `null`.
          expect(findModal().props('modal').vulnerability.dismissal_feedback).toBe(null);
        });

        it('handles undoing dismissing a finding - error', async () => {
          await createComponentExpandWidgetAndOpenModal({
            mockDataProps,
            enableStandaloneModal: false,
            additionalHandlers: [
              [revertFindingToDetectedMutation, jest.fn().mockRejectedValue({})],
            ],
          });

          findModal().vm.$emit('revertDismissVulnerability');

          await waitForPromises();

          expect(findModal().props('modal').error).toBe(
            'There was an error reverting the dismissal. Please try again.',
          );
        });
      });
    });
  });
});
