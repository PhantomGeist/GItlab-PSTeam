import { groupBy, uniqueId } from 'lodash';
import { ACCESS_LEVEL_LABELS } from '~/access_level/constants';
import { __, s__, sprintf } from '~/locale';
import {
  generateBadges as CEGenerateBadges,
  roleDropdownItems as CERoleDropdownItems,
  isDirectMember,
} from '~/members/utils';

export {
  isGroup,
  isDirectMember,
  isCurrentUser,
  canRemove,
  canRemoveBlockedByLastOwner,
  canResend,
  canUpdate,
} from '~/members/utils';

export const generateBadges = ({ member, isCurrentUser, canManageMembers }) => [
  ...CEGenerateBadges({ member, isCurrentUser, canManageMembers }),
  {
    show: member.usingLicense,
    text: __('Is using seat'),
    variant: 'neutral',
  },
  {
    show: member.groupSso,
    text: __('SAML'),
    variant: 'info',
  },
  {
    show: member.groupManagedAccount,
    text: __('Managed Account'),
    variant: 'info',
  },
  {
    show: member.canOverride,
    text: __('LDAP'),
    variant: 'info',
  },
  {
    show: member.provisionedByThisGroup,
    text: __('Enterprise'),
    variant: 'info',
  },
];

/**
 * Creates the dropdowns options for static and custom roles
 *
 * @param {object} member
 *   @param {Map<string, number>} member.validRoles
 *   @param {Array<{baseAccessLevel: number, name: string, memberRoleId: number}>} member.customRoles
 */
export const roleDropdownItems = ({ validRoles, customRoles }) => {
  if (!customRoles?.length) {
    return CERoleDropdownItems({ validRoles });
  }

  const { flatten: staticRoleDropdownItems } = CERoleDropdownItems({ validRoles });

  const customRoleDropdownItems = customRoles.map(({ baseAccessLevel, name, memberRoleId }) => ({
    accessLevel: baseAccessLevel,
    memberRoleId,
    text: name,
    value: uniqueId('role-custom-'),
  }));

  const customRoleDropdownGroups = Object.entries(
    groupBy(customRoleDropdownItems, 'accessLevel'),
  ).map(([accessLevel, options]) => ({
    text: sprintf(s__('MemberRoles|Custom roles based on %{accessLevel}'), {
      accessLevel: ACCESS_LEVEL_LABELS[accessLevel],
    }),
    options,
  }));

  return {
    flatten: [...staticRoleDropdownItems, ...customRoleDropdownItems],
    formatted: [
      {
        text: s__('MemberRoles|Standard roles'),
        options: staticRoleDropdownItems,
      },
      ...customRoleDropdownGroups,
    ],
  };
};

/**
 * Finds and returns unique value
 *
 * @param {Array<{accessLevel: number, memberRoleId: null|number, text: string, value: string}>} flattenDropdownItems
 * @param {object} member
 *   @param {{integerValue: number, memberRoleId: undefined|null|number}} member.accessLevel
 */
export const initialSelectedRole = (flattenDropdownItems, member) => {
  return flattenDropdownItems.find(
    ({ accessLevel, memberRoleId }) =>
      accessLevel === member.accessLevel.integerValue &&
      memberRoleId === (member.accessLevel.memberRoleId ?? null),
  )?.value;
};

export const canDisableTwoFactor = (member) => {
  return Boolean(member.canDisableTwoFactor);
};

export const canOverride = (member) => member.canOverride && isDirectMember(member);

export const canUnban = (member) => {
  return Boolean(member.banned) && member.canUnban;
};
