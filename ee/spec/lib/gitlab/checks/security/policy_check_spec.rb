# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::Security::PolicyCheck, '#validate!', feature_category: :security_policy_management do
  include RepoHelpers

  include_context 'change access checks context'

  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be_with_refind(:policy_project) { create(:project, :repository) }
  let_it_be_with_refind(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policy_project)
  end

  let!(:protected_branch) { project.protected_branches.create!(name: branch_name) }
  let(:force_push?) { true }
  let(:branch_name) { 'master' }

  subject(:policy_check!) { described_class.new(change_access).validate! }

  before do
    allow(Gitlab::Checks::ForcePush).to receive(:force_push?).with(project, oldrev, newrev).and_return(force_push?)

    stub_licensed_features(security_orchestration_policies: true)
  end

  context 'when unaffected by active scan result policy' do
    before do
      policy_configuration.delete
    end

    it 'does not raise' do
      expect { policy_check! }.not_to raise_error
    end
  end

  context 'when affected by active scan result policy' do
    include_context 'with scan result policy preventing force pushing'

    it 'raises' do
      expect { policy_check! }.to raise_error(Gitlab::GitAccess::ForbiddenError, described_class::ERROR_MESSAGE)
    end

    context 'when prevent_force_pushing setting is disabled' do
      let(:prevent_force_pushing) { false }

      it 'does not raise' do
        expect { policy_check! }.not_to raise_error
      end
    end

    context 'when branch is unprotected' do
      let!(:protected_branch) { nil }

      it 'does not raise' do
        expect { policy_check! }.not_to raise_error
      end
    end

    context 'when push is not forced' do
      let(:force_push?) { false }

      it 'does not raise' do
        expect { policy_check! }.not_to raise_error
      end
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(scan_result_policies_block_force_push: false)
      end

      it 'does not raise' do
        expect { policy_check! }.not_to raise_error
      end
    end

    context 'with licensed feature unavailable' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'does not raise' do
        expect { policy_check! }.not_to raise_error
      end
    end
  end
end
