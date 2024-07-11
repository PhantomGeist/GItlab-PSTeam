import {
  ACCESS_LEVEL_LABELS,
  ACCESS_LEVEL_DEVELOPER_INTEGER,
  ACCESS_LEVEL_GUEST_INTEGER,
  ACCESS_LEVEL_MAINTAINER_INTEGER,
  ACCESS_LEVEL_OWNER_INTEGER,
  ACCESS_LEVEL_REPORTER_INTEGER,
} from '~/access_level/constants';
import { __, s__ } from '~/locale';

export const BASE_ROLES = Object.freeze(
  [
    ACCESS_LEVEL_GUEST_INTEGER,
    ACCESS_LEVEL_REPORTER_INTEGER,
    ACCESS_LEVEL_DEVELOPER_INTEGER,
    ACCESS_LEVEL_MAINTAINER_INTEGER,
    ACCESS_LEVEL_OWNER_INTEGER,
  ].map((accessLevel) => ({ text: ACCESS_LEVEL_LABELS[accessLevel], value: accessLevel })),
);

export const READ_CODE = 'read_code';
export const READ_VULNERABILITY = 'read_vulnerability';
export const ADMIN_VULNERABILITY = 'admin_vulnerability';
export const MANAGE_PROJECT_ACCESS_TOKENS = 'manage_project_access_tokens';

export const PERMISSIONS = Object.freeze({
  [READ_CODE]: {
    help: s__('MemberRoles|Allows read-only access to the source code.'),
    text: s__('MemberRoles|Read code'),
    value: READ_CODE,
  },
  [READ_VULNERABILITY]: {
    help: s__('MemberRoles|Allows read-only access to the vulnerability reports.'),
    text: s__('MemberRoles|Read vulnerability'),
    value: READ_VULNERABILITY,
  },
  [ADMIN_VULNERABILITY]: {
    help: s__(
      "MemberRoles|Allows admin access to the vulnerability reports. Select 'Read vulnerability' for this to take effect.",
    ),
    text: s__('MemberRoles|Admin vulnerability'),
    value: ADMIN_VULNERABILITY,
  },
  [MANAGE_PROJECT_ACCESS_TOKENS]: {
    help: s__(
      "MemberRoles|Allows manage access to the project access tokens. Select 'Manage Project Access Tokens' for this to take effect.",
    ),
    text: s__('MemberRoles|Manage Project Access Tokens'),
    value: MANAGE_PROJECT_ACCESS_TOKENS,
  },
});

export const FIELDS = [
  {
    key: 'name',
    label: s__('MemberRoles|Name'),
    sortable: true,
  },
  {
    key: 'id',
    label: s__('MemberRoles|ID'),
    sortable: true,
  },
  {
    key: 'base_access_level',
    label: s__('MemberRoles|Base role'),
    sortable: true,
  },
  {
    key: 'permissions',
    label: s__('MemberRoles|Permissions'),
  },
  {
    key: 'actions',
    label: s__('MemberRoles|Actions'),
  },
];

// Translations
export const I18N_ADD_NEW_ROLE = s__('MemberRoles|Add new role');
export const I18N_CANCEL = __('Cancel');
export const I18N_CARD_TITLE = s__('MemberRoles|Custom roles');
export const I18N_CREATE_ROLE = s__('MemberRoles|Create new role');
export const I18N_CREATION_ERROR = s__('MemberRoles|Failed to create role.');
export const I18N_CREATION_SUCCESS = s__('MemberRoles|Role successfully created.');
export const I18N_DELETE_ROLE = s__('MemberRoles|Delete role');
export const I18N_DELETION_ERROR = s__('MemberRoles|Failed to delete the role.');
export const I18N_DELETION_SUCCESS = s__('MemberRoles|Role successfully deleted.');
export const I18N_EMPTY_TITLE = s__('MemberRoles|No custom roles for this group');
export const I18N_EMPTY_TEXT_SAAS = s__("MemberRoles|To add a new role select 'Add new role'.");
export const I18N_EMPTY_TEXT_SELF_MANAGED = s__(
  "MemberRoles|To add a new role select a group and then 'Add new role'.",
);
export const I18N_FETCH_ERROR = s__('MemberRoles|Failed to fetch roles.');
export const I18N_FIELD_FORM_ERROR = __('This field is required.');
export const I18N_LICENSE_ERROR = s__('MemberRoles|Make sure the group is in the Ultimate tier.');
export const I18N_MODAL_TITLE = s__('MemberRoles|Are you sure you want to delete this role?');
export const I18N_MODAL_WARNING = s__(
  `MemberRoles|To delete the custom role make sure no group member has this custom role`,
);
export const I18N_NEW_ROLE_BASE_ROLE_LABEL = s__('MemberRoles|Base role to use as template');
export const I18N_NEW_ROLE_BASE_ROLE_DESCRIPTION = s__(
  'MemberRoles|Select a standard role to add permissions.',
);
export const I18N_NEW_ROLE_DESCRIPTION_LABEL = s__('MemberRoles|Description');
export const I18N_NEW_ROLE_NAME_DESCRIPTION = s__('MemberRoles|Enter a short name.');
export const I18N_NEW_ROLE_NAME_LABEL = s__('MemberRoles|Role name');
export const I18N_NEW_ROLE_NAME_PLACEHOLDER = s__('MemberRoles|Incident manager');
export const I18N_NEW_ROLE_PERMISSIONS_LABEL = s__('MemberRoles|Permissions');
