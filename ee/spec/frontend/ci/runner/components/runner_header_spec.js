import { s__ } from '~/locale';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { UPGRADE_STATUS_AVAILABLE } from 'ee/ci/runner/constants';

import RunnerHeader from '~/ci/runner/components/runner_header.vue';
import RunnerUpgradeStatusBadge from 'ee_component/ci/runner/components/runner_upgrade_status_badge.vue';

import { runnerData } from 'jest/ci/runner/mock_data';

const mockRunner = runnerData.data.runner;

describe('RunnerHeader', () => {
  let wrapper;

  const findRunnerUpgradeStatusBadge = () => wrapper.findComponent(RunnerUpgradeStatusBadge);

  const createComponent = ({ runner = {}, ...options } = {}) => {
    wrapper = shallowMountExtended(RunnerHeader, {
      propsData: {
        runner: {
          ...mockRunner,
          ...runner,
        },
      },
      ...options,
    });
  };

  describe('Upgrade status', () => {
    describe.each`
      feature                                      | provide
      ${'runner_upgrade_management'}               | ${{ glFeatures: { runnerUpgradeManagement: true } }}
      ${'runner_upgrade_management_for_namespace'} | ${{ glFeatures: { runnerUpgradeManagementForNamespace: true } }}
    `('When $feature is available', ({ provide }) => {
      beforeEach(() => {
        createComponent({
          runner: {
            ...mockRunner,
            upgradeStatus: UPGRADE_STATUS_AVAILABLE,
          },
          provide,
        });
      });

      it('displays upgrade available badge', () => {
        expect(findRunnerUpgradeStatusBadge().text()).toContain(s__('Runners|Upgrade available'));
      });
    });
  });
});
