# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::ProtectedBranchesForcePushService, feature_category: :security_policy_management do
  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be(:policy_project) { create(:project, :repository) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }
  let(:branch_name) { protected_branch.name }
  let_it_be_with_refind(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: protected_branch.project,
      security_policy_management_project: policy_project)
  end

  subject(:result) { described_class.new(project: project).execute }

  before_all do
    project.repository.add_branch(project.creator, protected_branch.name, "HEAD")
  end

  context 'without blocking scan result policy' do
    it { is_expected.to be_empty }
  end

  context 'with blocking scan result policy' do
    include_context 'with scan result policy preventing force pushing'

    it 'includes the protected branch' do
      expect(result).to include(branch_name)
    end

    context 'with branch is not protected' do
      let(:branch_name) { 'feature-x' }

      it { is_expected.to be_empty }
    end

    context 'when policy is not preventing force pushing' do
      let(:prevent_force_pushing) { false }

      it { is_expected.to be_empty }
    end

    context 'when feature flag "scan_result_policies_block_force_push" is disabled' do
      before do
        stub_feature_flags(scan_result_policies_block_force_push: false)
      end

      it { is_expected.to be_empty }
    end
  end
end
