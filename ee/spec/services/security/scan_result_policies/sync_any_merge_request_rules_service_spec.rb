# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncAnyMergeRequestRulesService, feature_category: :security_policy_management do
  include RepoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :repository) }
  let(:service) { described_class.new(merge_request) }
  let_it_be(:merge_request, reload: true) { create(:ee_merge_request, source_project: project) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:approvals_required) { 1 }
    let(:signed_commit) { instance_double(Commit, has_signature?: true) }
    let(:unsigned_commit) { instance_double(Commit, has_signature?: false) }
    let_it_be(:protected_branch) do
      create(:protected_branch, name: merge_request.target_branch, project: project)
    end

    let_it_be(:scan_result_policy_read, reload: true) do
      create(:scan_result_policy_read, project: project)
    end

    let!(:approval_project_rule) do
      create(:approval_project_rule, :any_merge_request, project: project, approvals_required: approvals_required,
        applies_to_all_protected_branches: true, protected_branches: [protected_branch],
        scan_result_policy_read: scan_result_policy_read)
    end

    let!(:approver_rule) do
      create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
        approval_project_rule: approval_project_rule, approvals_required: approvals_required,
        scan_result_policy_read: scan_result_policy_read)
    end

    shared_examples_for 'does not update approval rules' do
      it 'does not update approval rules' do
        expect { execute }.not_to change { approver_rule.reload.approvals_required }
      end
    end

    shared_examples_for 'sets approvals_required to 0' do
      it 'sets approvals_required to 0' do
        expect { execute }.to change { approver_rule.reload.approvals_required }.to(0)
      end
    end

    context 'when merge_request is merged' do
      before do
        merge_request.update!(state: 'merged')
      end

      it_behaves_like 'does not update approval rules'
      it_behaves_like 'does not trigger policy bot comment'
    end

    describe 'approval rules' do
      context 'without violations' do
        context 'when policy targets unsigned commits and there are only signed commits in merge request' do
          before do
            scan_result_policy_read.update!(commits: :unsigned)
            allow(merge_request).to receive(:commits).and_return([signed_commit])
          end

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', :any_merge_request, false
          it_behaves_like 'merge request without scan result violations'

          it 'does not create a log' do
            expect(Gitlab::AppJsonLogger).not_to receive(:info)

            execute
          end
        end

        context 'when target branch is not protected' do
          before do
            scan_result_policy_read.update!(commits: :any)
            merge_request.update!(target_branch: 'non-protected')
          end

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', :any_merge_request, false
          it_behaves_like 'merge request without scan result violations'
        end
      end

      context 'with violations' do
        let(:policy_commits) { :any }
        let(:merge_request_commits) { [unsigned_commit] }

        before do
          scan_result_policy_read.update!(commits: policy_commits)
          allow(merge_request).to receive(:commits).and_return(merge_request_commits)
        end

        context 'when approvals are optional' do
          let(:approvals_required) { 0 }

          it_behaves_like 'does not update approval rules'
          it_behaves_like 'triggers policy bot comment', :any_merge_request, true, requires_approval: false
        end

        context 'when approval are required but approval_merge_request_rules have been made optional' do
          let!(:approval_project_rule) do
            create(:approval_project_rule, :any_merge_request, project: project, approvals_required: 1,
              scan_result_policy_read: scan_result_policy_read)
          end

          let!(:approver_rule) do
            create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
              approval_project_rule: approval_project_rule, approvals_required: 0,
              scan_result_policy_read: scan_result_policy_read)
          end

          it 'resets the required approvals' do
            expect { execute }.to change { approver_rule.reload.approvals_required }.to(1)
          end

          it_behaves_like 'triggers policy bot comment', :any_merge_request, true
        end

        where(:policy_commits, :merge_request_commits) do
          :unsigned | [ref(:unsigned_commit)]
          :unsigned | [ref(:signed_commit), ref(:unsigned_commit)]
          :any      | [ref(:signed_commit)]
          :any      | [ref(:unsigned_commit)]
        end

        with_them do
          it_behaves_like 'does not update approval rules'
          it_behaves_like 'triggers policy bot comment', :any_merge_request, true
          it_behaves_like 'merge request with scan result violations'

          it 'logs violated rules' do
            expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(message: 'Updating MR approval rule'))

            execute
          end
        end
      end

      describe 'policies with no approval rules' do
        let!(:approver_rule) { nil }

        context 'when policies target commits' do
          let_it_be(:scan_result_policy_read_with_commits, reload: true) do
            create(:scan_result_policy_read, project: project, commits: :unsigned, rule_idx: 0)
          end

          it 'creates violations for policies that have no approval rules' do
            expect { execute }.to change { merge_request.scan_result_policy_violations.count }.by(1)
            expect(merge_request.scan_result_policy_violations.first.scan_result_policy_read).to(
              eq scan_result_policy_read_with_commits
            )
          end

          context 'with previous violation for policy that is now unviolated' do
            let!(:unrelated_violation) do
              create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read_with_commits,
                merge_request: merge_request)
            end

            before do
              allow(merge_request).to receive(:commits).and_return([signed_commit])
            end

            it 'removes the violation record' do
              expect { execute }.to change { merge_request.scan_result_policy_violations.count }.by(-1)
            end
          end

          context 'when target branch is not protected' do
            let_it_be(:policy_project) { create(:project, :repository) }
            let_it_be(:policy_configuration) do
              create(:security_orchestration_policy_configuration,
                project: project,
                security_policy_management_project: policy_project)
            end

            let(:scan_result_policy) { build(:scan_result_policy, :any_merge_request, branches: ['protected']) }
            let(:policy_yaml) do
              build(:orchestration_policy_yaml, scan_result_policy: [scan_result_policy])
            end

            before do
              merge_request.update!(target_branch: 'non-protected')
              allow_next_instance_of(Repository) do |repository|
                allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
              end
            end

            it_behaves_like 'triggers policy bot comment', :any_merge_request, false
            it_behaves_like 'merge request without scan result violations' do
              let(:scan_result_policy_read) { scan_result_policy_read_with_commits }
            end
          end

          context 'when there are other approval rules' do
            let_it_be(:scan_finding_project_rule) do
              create(:approval_project_rule, :scan_finding, project: project,
                scan_result_policy_read: scan_result_policy_read_with_commits, approvals_required: 1)
            end

            let!(:another_approver_rule) { approver_rule }

            let_it_be(:license_scanning_project_rule) do
              create(:approval_project_rule, :scan_finding, project: project,
                scan_result_policy_read: scan_result_policy_read_with_commits, approvals_required: 1)
            end

            let_it_be(:scan_finding_merge_request_rule) do
              create(:report_approver_rule, :scan_finding, merge_request: merge_request,
                approval_project_rule: scan_finding_project_rule, approvals_required: 0,
                scan_result_policy_read: scan_result_policy_read_with_commits)
            end

            let_it_be(:license_scanning_merge_request_rule) do
              create(:report_approver_rule, :license_scanning, merge_request: merge_request,
                approval_project_rule: license_scanning_project_rule, approvals_required: 0,
                scan_result_policy_read: scan_result_policy_read_with_commits)
            end

            it 'does not reset required approvals' do
              execute

              expect(scan_finding_merge_request_rule.reload.approvals_required).to eq 0
              expect(license_scanning_merge_request_rule.reload.approvals_required).to eq 0
            end
          end
        end

        context 'when the policies are not targeting commits' do
          before do
            scan_result_policy_read.update!(commits: nil)
          end

          it_behaves_like 'merge request without scan result violations', previous_violation: false
        end
      end
    end
  end
end
