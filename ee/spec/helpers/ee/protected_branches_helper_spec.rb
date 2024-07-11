# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranchesHelper, feature_category: :source_code_management do
  describe '#allow_protected_branch_force_push?' do
    subject { helper.allow_protected_branch_force_push?(branches_protected_from_force_push, protected_branch) }

    let(:branches_protected_from_force_push) { %w[main feature-a] }
    let(:protected_branch) { build(:protected_branch, name: 'main') }

    it { is_expected.to eq false }

    context 'when there are no branches protected from force push' do
      let(:branches_protected_from_force_push) { [] }

      it { is_expected.to eq true }
    end

    context 'when branch is not included in the list' do
      let(:branches_protected_from_force_push) { %w[feature-a] }

      it { is_expected.to eq true }
    end

    context 'when branches_protected_from_force_push are nil' do
      let(:branches_protected_from_force_push) { nil }

      it { is_expected.to eq true }
    end
  end
end
