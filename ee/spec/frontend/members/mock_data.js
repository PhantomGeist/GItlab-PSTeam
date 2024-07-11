import { member } from 'jest/members/mock_data';

export * from 'jest/members/mock_data';

export const bannedMember = {
  ...member,
  banned: true,
};

export const customRoles = [
  { baseAccessLevel: 20, name: 'c', memberRoleId: 103 },
  { baseAccessLevel: 10, name: 'a', memberRoleId: 101 },
  { baseAccessLevel: 10, name: 'b', memberRoleId: 102 },
];

export const upgradedMember = { ...member, customRoles };
