import { s__ } from '~/locale';

// https://docs.gitlab.com/ee/user/usage_quotas#project-storage-limit
// declared in ee/app/models/namespaces/storage/root_excess_size.rb
export const PROJECT_ENFORCEMENT_TYPE = 'project_repository_limit';
export const PROJECT_ENFORCEMENT_TYPE_CARD_SUBTITLE = s__(
  'UsageQuota|Namespace total storage represents the sum of storage consumed by all projects, Container Registry, and Dependency Proxy.',
);

// https://docs.gitlab.com/ee/user/usage_quotas#namespace-storage-limit
// declared in ee/app/models/namespaces/storage/root_size.rb
export const NAMESPACE_ENFORCEMENT_TYPE = 'namespace_storage_limit';

export const STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE = s__(
  'UsageQuota|Learn more about usage quotas.',
);

export const NAMESPACE_STORAGE_OVERVIEW_SUBTITLE = s__('UsageQuota|Namespace overview');
export const NAMESPACE_STORAGE_BREAKDOWN_SUBTITLE = s__('UsageQuota|Storage usage breakdown');
export const NAMESPACE_STORAGE_ERROR_MESSAGE = s__(
  'UsageQuota|Something went wrong while loading usage details',
);

export const STORAGE_STATISTICS_NAMESPACE_STORAGE_USED = s__('UsageQuota|Namespace storage used');
export const STORAGE_STATISTICS_PERCENTAGE_REMAINING = s__(
  'UsageQuota|%{percentageRemaining}%% namespace storage remaining.',
);

export const STORAGE_STATISTICS_TOTAL_STORAGE = s__('UsageQuota|Total storage');

export const STORAGE_STATISTICS_PURCHASED_STORAGE = s__('UsageQuota|Total purchased storage');

export const BUY_STORAGE = s__('UsageQuota|Buy storage');
