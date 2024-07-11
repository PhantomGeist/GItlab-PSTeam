# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalWrappedRule, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  let(:merge_request) { create(:merge_request) }
  let(:rule) { create(:approval_merge_request_rule, merge_request: merge_request, approvals_required: approvals_required) }
  let(:approvals_required) { 0 }
  let(:approver1) { create(:user) }
  let(:approver2) { create(:user) }
  let(:approver3) { create(:user) }

  subject(:approval_wrapped_rule) { described_class.new(merge_request, rule) }

  before do
    rule.clear_memoization(:approvers) if rule.respond_to?(:clear_memoization)
  end

  describe '#project' do
    it 'returns merge request project' do
      expect(approval_wrapped_rule.project).to eq(merge_request.target_project)
    end
  end

  describe '#approvals_left' do
    before do
      create(:approval, merge_request: merge_request, user: approver1)
      create(:approval, merge_request: merge_request, user: approver2)
      rule.users << approver1
      rule.users << approver2
    end

    context 'when approvals_required is greater than approved approver count' do
      let(:approvals_required) { 8 }

      it 'returns approvals still needed' do
        expect(approval_wrapped_rule.approvals_left).to eq(6)
      end
    end

    context 'when approvals_required is less than approved approver count' do
      let(:approvals_required) { 1 }

      it 'returns zero' do
        expect(approval_wrapped_rule.approvals_left).to eq(0)
      end
    end
  end

  describe '#approved?' do
    subject { described_class.new(merge_request, rule).approved? }

    before do
      create(:approval, merge_request: merge_request, user: approver1)
      rule.users << approver1
    end

    context 'when approvals left is zero' do
      let(:approvals_required) { 1 }

      it { is_expected.to eq(true) }
    end

    context 'when approvals left is not zero, but there is still unactioned approvers' do
      let(:approvals_required) { 2 }

      before do
        rule.users << approver2
      end

      it { is_expected.to eq(false) }
    end

    context 'when approvals left is not zero, but there is no unactioned approvers' do
      let(:approvals_required) { 99 }

      it { is_expected.to eq(true) }
    end

    context 'when approvals left is not zero, but there is not enough unactioned approvers' do
      let(:approvals_required) { 99 }

      before do
        rule.users << approver2
      end

      it { is_expected.to eq(true) }
    end
  end

  describe '#invalid_rule?' do
    subject { described_class.new(merge_request, rule).invalid_rule? }

    context 'when there are no unactioned approvers and approvals are required' do
      let(:approvals_required) { 1 }

      it { is_expected.to eq(true) }
    end

    context 'when rule is any_approver and approvals are required' do
      let(:rule) { create(:any_approver_rule, merge_request: merge_request, approvals_required: 1) }

      it { is_expected.to eq(false) }
    end

    context 'when more approvals are required than the number of approvers' do
      let(:approvals_required) { 2 }

      before do
        rule.users << approver1
      end

      it { is_expected.to eq(true) }
    end

    context 'when there are unactioned approvers and approvals are required' do
      let(:approvals_required) { 1 }

      before do
        rule.users << approver1
      end

      it { is_expected.to eq(false) }
    end

    context 'when there are no unactioned approvers because all required approvals are given' do
      let(:approvals_required) { 1 }

      before do
        create(:approval, merge_request: merge_request, user: approver1)
        rule.users << approver1
      end

      it { is_expected.to eq(false) }
    end

    context 'when there are more approvers than required approvals' do
      let(:approvals_required) { 1 }

      before do
        rule.users << approver1
        rule.users << approver2
      end

      it { is_expected.to eq(false) }
    end

    context 'when no approvals are required' do
      let(:approvals_required) { 0 }

      it { is_expected.to eq(false) }
    end
  end

  describe '#allow_merge_when_invalid?' do
    subject { described_class.new(merge_request, rule).allow_merge_when_invalid? }

    context 'when report_type is scan_finding' do
      let(:rule) { create(:report_approver_rule, :scan_finding) }

      it { is_expected.to eq(false) }
    end

    context 'when report_type is license_scanning and scan_result_policy_read is attached' do
      let(:rule) do
        create(:report_approver_rule, :license_scanning, scan_result_policy_read: scan_result_policy_read)
      end

      let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read) }

      it { is_expected.to eq(false) }
    end

    context 'when report_type is any_merge_request' do
      let(:rule) { create(:report_approver_rule, :any_merge_request) }

      it { is_expected.to eq(false) }

      context 'when feature flag "scan_result_any_merge_request" is disabled' do
        before do
          stub_feature_flags(scan_result_any_merge_request: false)
        end

        it { is_expected.to eq(true) }
      end
    end

    context 'when report_type is nil' do
      let(:rule) { create(:approval_merge_request_rule, report_type: nil) }

      it { is_expected.to eq(true) }
    end

    context 'when project is a policy management project' do
      before do
        create(:security_orchestration_policy_configuration, security_policy_management_project: merge_request.project)
      end

      let(:rule) do
        create(:report_approver_rule, :scan_finding)
      end

      it { is_expected.to eq(true) }
    end
  end

  describe '#approved_approvers' do
    context 'when some approvers has made the approvals' do
      before do
        create(:approval, merge_request: merge_request, user: approver1)
        create(:approval, merge_request: merge_request, user: approver2)

        rule.users = [approver1, approver3]
      end

      it 'returns approved approvers' do
        expect(approval_wrapped_rule.approved_approvers).to contain_exactly(approver1)
      end
    end

    context 'when merged' do
      let(:merge_request) { create(:merged_merge_request) }

      before do
        rule.approved_approvers << approver3
      end

      it 'returns approved approvers from database' do
        expect(approval_wrapped_rule.approved_approvers).to contain_exactly(approver3)
      end
    end

    context 'when merged but without materialized approved_approvers' do
      let(:merge_request) { create(:merged_merge_request) }

      before do
        create(:approval, merge_request: merge_request, user: approver1)
        create(:approval, merge_request: merge_request, user: approver2)

        rule.users = [approver1, approver3]
      end

      it 'returns computed approved approvers' do
        expect(approval_wrapped_rule.approved_approvers).to contain_exactly(approver1)
      end
    end

    context 'when project rule' do
      let(:rule) { create(:approval_project_rule, project: merge_request.project, approvals_required: approvals_required) }
      let(:merge_request) { create(:merged_merge_request) }

      before do
        create(:approval, merge_request: merge_request, user: approver1)
        create(:approval, merge_request: merge_request, user: approver2)

        rule.users = [approver1, approver3]
      end

      it 'returns computed approved approvers' do
        expect(approval_wrapped_rule.approved_approvers).to contain_exactly(approver1)
      end
    end

    it 'avoids N+1 queries' do
      rule = create(:approval_project_rule, project: merge_request.project, approvals_required: approvals_required)
      rule.users = [approver1]

      approved_approvers_for_rule_id(rule.id) # warm up the cache
      control_count = ActiveRecord::QueryRecorder.new { approved_approvers_for_rule_id(rule.id) }.count

      rule.users += [approver2, approver3]

      expect { approved_approvers_for_rule_id(rule.id) }.not_to exceed_query_limit(control_count)
    end

    def approved_approvers_for_rule_id(rule_id)
      described_class.new(merge_request, ApprovalProjectRule.find(rule_id)).approved_approvers
    end
  end

  describe "#commented_approvers" do
    let(:rule) { create(:approval_project_rule, project: merge_request.project, approvals_required: approvals_required, users: [approver1, approver3]) }

    it "returns an array" do
      expect(approval_wrapped_rule.commented_approvers).to be_an(Array)
    end

    it "returns an array of approvers who have commented" do
      non_approver = create(:user)
      create(:note, project: merge_request.project, noteable: merge_request, author: approver1)
      create(:note, project: merge_request.project, noteable: merge_request, author: non_approver)
      create(:system_note, project: merge_request.project, noteable: merge_request, author: approver3)

      expect(approval_wrapped_rule.commented_approvers).to include(approver1)
      expect(approval_wrapped_rule.commented_approvers).not_to include(non_approver)
      expect(approval_wrapped_rule.commented_approvers).not_to include(approver3)
    end
  end

  describe '#unactioned_approvers' do
    context 'when some approvers has not approved yet' do
      before do
        create(:approval, merge_request: merge_request, user: approver1)
        rule.users = [approver1, approver2]
      end

      it 'returns unactioned approvers' do
        expect(approval_wrapped_rule.unactioned_approvers).to contain_exactly(approver2)
      end
    end

    context 'when merged' do
      let(:merge_request) { create(:merged_merge_request) }

      before do
        rule.approved_approvers << approver3
        rule.users = [approver1, approver3]
      end

      it 'returns approved approvers from database' do
        expect(approval_wrapped_rule.unactioned_approvers).to contain_exactly(approver1)
      end
    end
  end

  describe '#approvals_required' do
    let(:rule) { create(:approval_merge_request_rule, approvals_required: 19) }

    it 'returns the attribute saved on the model' do
      expect(approval_wrapped_rule.approvals_required).to eq(19)
    end
  end

  describe '#name' do
    let(:rule_name) { 'approval rule 2' }
    let(:rule) { create(:approval_merge_request_rule, report_type: report_type, name: rule_name) }

    context 'with report_type set to scan_finding' do
      let(:report_type) { :scan_finding }
      let(:expected_rule_name) { 'approval rule' }

      it 'returns rule name without the sequential notation' do
        expect(approval_wrapped_rule.name).not_to eq(rule_name)
        expect(approval_wrapped_rule.name).to eq(expected_rule_name)
      end
    end

    context 'with report_type other than scan_finding' do
      let(:report_type) { :code_coverage }

      it 'returns rule name as is' do
        expect(approval_wrapped_rule.name).to eq(rule_name)
      end
    end

    context 'with report_type set to license_scanning' do
      let(:report_type) { :license_scanning }
      let(:expected_rule_name) { 'approval rule' }

      let(:rule) do
        create(:approval_merge_request_rule,
          report_type: report_type,
          scan_result_policy_read: create(:scan_result_policy_read),
          name: rule_name)
      end

      it 'returns rule name without the sequential notation' do
        expect(approval_wrapped_rule.name).not_to eq(rule_name)
        expect(approval_wrapped_rule.name).to eq(expected_rule_name)
      end
    end
  end
end
