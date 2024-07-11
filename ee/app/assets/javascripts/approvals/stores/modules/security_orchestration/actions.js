import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import projectScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_result_policies.query.graphql';
import { fromYaml } from 'ee/security_orchestration/components/policy_editor/scan_result/lib/from_yaml';
import { gqClient } from 'ee/security_orchestration/utils';
import * as types from './mutation_types';

export const fetchScanResultPolicies = ({ commit }, { fullPath }) => {
  gqClient
    .query({
      query: projectScanResultPoliciesQuery,
      variables: { fullPath },
    })
    .then(({ data }) => {
      const policies = data.namespace?.scanResultPolicies?.nodes || [];
      const parsedPolicies = policies
        .map((rawPolicy) => {
          try {
            return {
              ...fromYaml({ manifest: rawPolicy.yaml }),
              isSelected: false,
              approvers: [...rawPolicy.userApprovers, ...rawPolicy.allGroupApprovers],
              editPath: rawPolicy.editPath,
              source: rawPolicy.source || { project: { fullPath } },
            };
          } catch (e) {
            return null;
          }
        })
        .filter((policy) => policy);
      commit(types.SET_SCAN_RESULT_POLICIES, parsedPolicies);
    })
    .catch((error) => {
      commit(types.SCAN_RESULT_POLICIES_FAILED, error);
      createAlert({
        message: s__(
          'SecurityOrchestration|An error occurred while fetching the scan result policies.',
        ),
      });
      Sentry.captureException(error);
    });
};
