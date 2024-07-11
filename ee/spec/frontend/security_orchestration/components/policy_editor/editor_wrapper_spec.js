import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import EditorWrapper from 'ee/security_orchestration/components/policy_editor/editor_wrapper.vue';
import ScanExecutionPolicyEditor from 'ee/security_orchestration/components/policy_editor/scan_execution/editor_component.vue';
import ScanResultPolicyEditor from 'ee/security_orchestration/components/policy_editor/scan_result/editor_component.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import { mockDastScanExecutionObject } from '../../mocks/mock_scan_execution_policy_data';

describe('EditorWrapper component', () => {
  let wrapper;

  const findGroupLevelNotification = () => wrapper.findByTestId('group-level-notification');
  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findScanExecutionPolicyEditor = () => wrapper.findComponent(ScanExecutionPolicyEditor);
  const findScanResultPolicyEditor = () => wrapper.findComponent(ScanResultPolicyEditor);

  const factory = ({ provide = {}, propsData = {} } = {}) => {
    wrapper = shallowMountExtended(EditorWrapper, {
      propsData: {
        selectedPolicyType: 'container',
        ...propsData,
      },
      provide: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        policyType: undefined,
        ...provide,
      },
    });
  };

  describe('when there is no existingPolicy', () => {
    describe('project-level', () => {
      beforeEach(factory);

      it.each`
        component              | findComponent
        ${'group-level alert'} | ${findGroupLevelNotification}
        ${'error alert'}       | ${findErrorAlert}
      `('does not display the $component', ({ findComponent }) => {
        expect(findComponent().exists()).toBe(false);
      });

      it('renders the policy editor component', () => {
        expect(findScanExecutionPolicyEditor().props('existingPolicy')).toBe(null);
      });

      it('shows an alert when "error" is emitted from the component', async () => {
        const errorMessage = 'test';
        findScanExecutionPolicyEditor().vm.$emit('error', errorMessage);
        await nextTick();
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe(errorMessage);
      });

      it('shows an alert with details when multiline "error" is emitted from the component', async () => {
        const errorMessages = 'title\ndetail1';
        findScanExecutionPolicyEditor().vm.$emit('error', errorMessages);
        await nextTick();
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('title');
        expect(alert.text()).toBe('detail1');
      });

      it.each`
        policyTypeId                                         | findComponent
        ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value} | ${findScanExecutionPolicyEditor}
        ${POLICY_TYPE_COMPONENT_OPTIONS.scanResult.value}    | ${findScanResultPolicyEditor}
      `(
        'renders the policy editor of type $policyType when selected',
        async ({ findComponent, policyTypeId }) => {
          factory({ propsData: { selectedPolicyType: policyTypeId } });
          await nextTick();
          const component = findComponent();
          expect(component.exists()).toBe(true);
          expect(component.props('isEditing')).toBe(false);
        },
      );
    });

    describe('group-level', () => {
      beforeEach(() => {
        factory({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
      });

      it('does display the group-level alert', () => {
        expect(findGroupLevelNotification().exists()).toBe(true);
      });
    });
  });

  describe('when there is existingPolicy attached', () => {
    beforeEach(() => {
      factory({ provide: { existingPolicy: mockDastScanExecutionObject } });
    });

    it('renders the policy editor for editing', () => {
      expect(findScanExecutionPolicyEditor().props('isEditing')).toBe(true);
    });
  });
});
