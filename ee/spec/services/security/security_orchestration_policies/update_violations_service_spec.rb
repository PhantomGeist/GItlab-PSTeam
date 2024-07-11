# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::UpdateViolationsService, '#execute', feature_category: :security_policy_management do
  let(:service) { described_class.new(merge_request) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request, reload: true) do
    create(:merge_request, source_project: project, target_project: project)
  end

  let_it_be(:policy_a) { create(:scan_result_policy_read, project: project) }
  let_it_be(:policy_b) { create(:scan_result_policy_read, project: project) }

  subject(:violated_policies) { merge_request.scan_result_policy_violations.map(&:scan_result_policy_read) }

  describe 'attributes' do
    subject(:attrs) { project.scan_result_policy_violations.last.attributes }

    before do
      service.add([policy_b.id], [])
      service.execute
    end

    specify do
      is_expected.to include(
        "scan_result_policy_id" => kind_of(Numeric),
        "merge_request_id" => kind_of(Numeric),
        "project_id" => kind_of(Numeric))
    end
  end

  context 'without pre-existing violations' do
    it 'creates violations' do
      service.add([policy_b.id], [])
      service.execute

      expect(violated_policies).to contain_exactly(policy_b)
    end
  end

  context 'with pre-existing violations' do
    before do
      service.add([policy_a.id], [])
      service.execute
    end

    it 'clears existing violations' do
      service.add([policy_b.id], [policy_a.id])
      service.execute

      expect(violated_policies).to contain_exactly(policy_b)
    end

    context 'with identical state' do
      it 'does not clear violations' do
        service.add([policy_a.id], [])
        service.execute

        expect(violated_policies).to contain_exactly(policy_a)
      end
    end
  end

  context 'with unrelated existing violation' do
    let_it_be(:unrelated_violation) do
      create(:scan_result_policy_violation, scan_result_policy_read: policy_a, merge_request: merge_request)
    end

    before do
      service.add([], [policy_b.id])
    end

    it 'removes only violations provided in unviolated ids' do
      service.execute

      expect(merge_request.scan_result_policy_violations).to contain_exactly(unrelated_violation)
    end
  end

  context 'without violations' do
    it 'clears all violations' do
      service.execute

      expect(violated_policies).to be_empty
    end
  end
end
