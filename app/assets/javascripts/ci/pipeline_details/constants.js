import { __, s__ } from '~/locale';

export const CANCEL_REQUEST = 'CANCEL_REQUEST';
export const SUPPORTED_FILTER_PARAMETERS = ['username', 'ref', 'status', 'source'];
export const NEEDS_PROPERTY = 'needs';
export const EXPLICIT_NEEDS_PROPERTY = 'previousStageJobsOrNeeds';

export const TestStatus = {
  FAILED: 'failed',
  SKIPPED: 'skipped',
  SUCCESS: 'success',
  ERROR: 'error',
  UNKNOWN: 'unknown',
};

/* Error constants shared across graphs */
export const DEFAULT = 'default';
export const DELETE_FAILURE = 'delete_pipeline_failure';
export const DRAW_FAILURE = 'draw_failure';
export const LOAD_FAILURE = 'load_failure';
export const PARSE_FAILURE = 'parse_failure';
export const POST_FAILURE = 'post_failure';
export const UNSUPPORTED_DATA = 'unsupported_data';

// Pipeline tabs

export const pipelineTabName = 'graph';
export const needsTabName = 'dag';
export const jobsTabName = 'builds';
export const failedJobsTabName = 'failures';
export const testReportTabName = 'test_report';
export const securityTabName = 'security';
export const licensesTabName = 'licenses';
export const codeQualityTabName = 'codequality_report';

export const validPipelineTabNames = [
  needsTabName,
  jobsTabName,
  failedJobsTabName,
  testReportTabName,
  securityTabName,
  licensesTabName,
  codeQualityTabName,
];

export const TOAST_MESSAGE = s__('Pipeline|Creating pipeline.');

export const DEFAULT_FIELDS = [
  {
    key: 'name',
    label: __('Name'),
    columnClass: 'gl-w-20p',
  },
  {
    key: 'stage',
    label: __('Stage'),
    columnClass: 'gl-w-20p',
  },
  {
    key: 'failureMessage',
    label: __('Failure'),
    columnClass: 'gl-w-40p',
  },
  {
    key: 'actions',
    label: '',
    tdClass: 'gl-text-right',
    columnClass: 'gl-w-20p',
  },
];

// Pipeline Mini Graph

export const PIPELINE_MINI_GRAPH_POLL_INTERVAL = 5000;
