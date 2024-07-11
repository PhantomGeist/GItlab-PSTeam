# frozen_string_literal: true

require 'spec_helper'

# rubocop: disable RSpec/DuplicateSpecLocation
RSpec.describe Branches::DeleteService, feature_category: :source_code_management do
  describe '#execute' do
    subject(:execute_service) { described_class.new(project, user).execute(protected_branch_name) }

    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:user) { create(:user) }

    let!(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let!(:protected_branch) { create(:protected_branch, name: protected_branch_name, project: project) }
    let(:protected_branch_name) { 'protected_branch' }

    before_all do
      project.add_developer(user)
    end

    before do
      project.repository.create_branch(protected_branch_name, project.default_branch_or_main)
    end

    it 'deletes the branch' do
      expect(execute_service.status).to eq :success
    end

    context 'with scan result policy blocking protected branches' do
      include_context 'with scan result policy blocking protected branches'

      let(:branch_name) { protected_branch_name }

      it 'does not allow delete', :aggregate_failures do
        result = execute_service

        expect(result.status).to eq :error
        expect(result.message).to eq 'Deleting protected branches is blocked by security policies'
        expect(result.reason).to eq :forbidden
      end

      context 'when the scan_result_policies_block_unprotecting_branches feature is not available' do
        before do
          stub_feature_flags(scan_result_policies_block_unprotecting_branches: false)
        end

        it 'deletes the branch' do
          expect(execute_service.status).to eq :success
        end
      end

      context 'when the security_orchestration_policies feature is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'deletes the branch' do
          expect(execute_service.status).to eq :success
        end
      end

      context 'when branch is not included in security policy' do
        include_context 'with scan result policy blocking protected branches' do
          let(:branch_name) { 'some other branch' }
        end

        it 'deletes the branch' do
          expect(execute_service.status).to eq :success
        end
      end

      context 'with branch exceptions' do
        include_context 'with scan result policy blocking protected branches' do
          let(:rules) do
            [
              {
                type: 'scan_finding',
                branch_type: 'protected',
                branch_exceptions: [branch_name],
                scanners: %w[container_scanning],
                vulnerabilities_allowed: 0,
                severity_levels: %w[critical],
                vulnerability_states: %w[detected],
                vulnerability_attributes: {}
              }
            ]
          end

          let(:scan_result_policy) do
            build(:scan_result_policy, rules: rules, approval_settings: { block_unprotecting_branches: true })
          end
        end

        it 'deletes the branch' do
          expect(execute_service.status).to eq :success
        end
      end
    end
  end
end
# rubocop: enable RSpec/DuplicateSpecLocation
