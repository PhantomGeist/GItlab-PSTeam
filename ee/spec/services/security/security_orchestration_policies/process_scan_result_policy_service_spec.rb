# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService, feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be_with_refind(:group) { create(:group, :public) }
    let_it_be_with_refind(:project) { create(:project, :empty_repo, namespace: group) }

    let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let(:policy) { build(:scan_result_policy, name: 'Test Policy') }
    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(policy.to_yaml).load! }
    let_it_be(:approver) { create(:user) }
    let(:service) { described_class.new(project: project, policy_configuration: policy_configuration, policy: policy, policy_index: 0) }

    RSpec.shared_context 'with existing branch' do
      let(:branch_name) { name }

      before do
        project.repository.add_branch(project.creator, branch_name, project.repository.head_commit.sha)
      end

      after do
        project.repository.delete_branch(branch_name)
      end
    end

    before_all do
      group.add_maintainer(approver)

      sha = project.repository.create_file(
        project.creator,
        "README.md",
        "",
        message: "initial commit",
        branch_name: 'master')

      create(:protected_branch, name: 'master', project: project)
      project.repository.add_branch(project.creator, 'master', sha)
    end

    before do
      allow(project).to receive(:multiple_approval_rules_available?).and_return(true)
      allow(policy_configuration).to receive(:policy_last_updated_by).and_return(approver)
    end

    subject { service.execute }

    context 'when actions are not provided' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: nil) }

      it 'creates approval rules' do
        expect { subject }.to change { project.approval_rules.count }.by(1)
      end

      it 'sets approvals_required to 0' do
        subject

        expect(project.approval_rules.last.approvals_required).to be(0)
      end
    end

    context 'without any require_approval action' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'another_one' }]) }

      it 'creates approval rules' do
        expect { subject }.to change { project.approval_rules.count }.by(1)
      end

      it 'sets approvals_required to 0' do
        subject

        expect(project.approval_rules.last.approvals_required).to be(0)
      end
    end

    context 'without any rule of the scan_finding type' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', rules: [{ type: 'another_one' }]) }

      it 'does not create approval project rules' do
        expect { subject }.not_to change { project.approval_rules.count }
      end
    end

    shared_examples 'create approval rule with specific approver' do
      it 'succeeds creating approval rules with specific approver' do
        expect { subject }.to change { project.approval_rules.count }.by(1)
        expect(project.approval_rules.first.approvers).to contain_exactly(approver)
      end
    end

    context 'with only user id' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, user_approvers_ids: [approver.id] }]) }

      it_behaves_like 'create approval rule with specific approver'
    end

    context 'with only username' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, user_approvers: [approver.username] }]) }

      it_behaves_like 'create approval rule with specific approver'
    end

    context 'with role_approvers' do
      let(:policy) do
        build(:scan_result_policy,
          name: 'Test Policy',
          actions: [{
            type: 'require_approval',
            approvals_required: 1,
            user_approvers: [approver.username],
            role_approvers: ['developer']
          }]
        )
      end

      let_it_be(:developer) { create(:user) }

      before do
        project.add_developer(developer)
      end

      it 'creates approval rules with role approvers' do
        expect { subject }.to change { project.approval_rules.count }.by(1)
        expect(project.approval_rules.first.approvers).to contain_exactly(approver, developer)
      end

      it 'creates scan_result_policy_read' do
        expect { subject }.to change { Security::ScanResultPolicyRead.count }.by(1)
        expect(project.approval_rules.first.scan_result_policy_read.role_approvers).to match_array([Gitlab::Access::DEVELOPER])
      end
    end

    context 'with only group id' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, group_approvers_ids: [group.id] }]) }

      it_behaves_like 'create approval rule with specific approver'

      context 'with public group outside of the scope' do
        let(:another_group) { create(:group, :public) }
        let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, group_approvers_ids: [another_group.id] }]) }

        it 'does not include any approvers' do
          subject

          expect(project.approval_rules.first.approvers).to be_empty
        end
      end

      context 'with private group outside of the scope' do
        let(:another_group) { create(:group, :private) }
        let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, group_approvers_ids: [another_group.id] }]) }

        it 'does not include any approvers' do
          subject

          expect(project.approval_rules.first.approvers).to be_empty
        end
      end

      context 'with an invited group' do
        let(:group_user) { create(:user) }
        let(:another_group) { create(:group, :public) }
        let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, group_approvers_ids: [another_group.id] }]) }

        before do
          another_group.add_maintainer(group_user)
          project.invited_groups = [another_group]
        end

        it 'includes group related approvers' do
          subject

          expect(project.approval_rules.first.approvers).to match_array([group_user])
        end
      end
    end

    context 'with only group path' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, group_approvers: [group.path] }]) }

      it_behaves_like 'create approval rule with specific approver'

      context 'when groups with same name exist in and outside of container' do
        let(:other_container) { create(:group) }
        let(:other_group) { create(:group, name: group.name, parent: other_container) }
        let(:other_user) { create(:user) }
        let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, group_approvers: [group.name] }]) }

        before do
          other_group.add_developer(other_user)
        end

        context 'with security_policy_global_group_approvers_enabled setting disabled' do
          before do
            stub_ee_application_setting(security_policy_global_group_approvers_enabled: false)
          end

          it 'excludes groups outside the container' do
            subject

            expect(project.approval_rules.first.approvers).not_to include(other_user)
          end
        end

        context 'with security_policy_global_group_approvers_enabled setting enabled' do
          before do
            stub_ee_application_setting(security_policy_global_group_approvers_enabled: true)
          end

          it 'includes groups outside the container' do
            subject

            expect(project.approval_rules.first.approvers).to include(other_user)
          end
        end
      end
    end

    context 'when rules are not provided' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval' }], rules: nil) }

      it 'does not create approval project rules' do
        expect { subject }.not_to change { project.approval_rules.count }
      end
    end

    context 'when rules are provided' do
      let(:rule) do
        {
          type: 'scan_finding',
          branches: %w[master],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: vulnerability_states
        }
      end

      let(:policy) { build(:scan_result_policy, name: 'Test Policy', rules: [rule]) }

      context 'with valid vulnerability_states' do
        states_list = [
          %w[newly_detected],
          %w[detected],
          %w[dismissed],
          %w[resolved],
          %w[confirmed],
          %w[new_dismissed],
          %w[new_needs_triage],
          %w[new_dismissed new_needs_triage],
          %w[detected dismissed confirmed resolved],
          %w[confirmed dismissed]
        ]

        states_list.each do |states|
          context "with #{states}" do
            let(:vulnerability_states) { states }

            it 'creates new approval rules' do
              expect { subject }.to change { project.approval_rules.count }.by(1)
            end
          end
        end
      end

      context 'with invalid vulnerability_states' do
        let(:vulnerability_states) { ['invalid_state'] }

        it 'creates no approval rules' do
          expect { subject }.not_to change { project.approval_rules.count }
        end
      end
    end

    context 'with vulnerability_attributes' do
      let(:vulnerability_attributes) { { false_positive: true, fix_available: false } }
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', vulnerability_attributes: vulnerability_attributes) }

      it 'creates approval rules' do
        expect { subject }.to change { project.approval_rules.count }.by(1)

        expect(project.approval_rules.last.vulnerability_attributes).to eq({ 'false_positive' => true, 'fix_available' => false })
      end

      it 'creates a ScanResultPolicyRead' do
        expect { subject }.to change { project.security_orchestration_policy_configuration.scan_result_policy_reads.count }.by(1)

        expect(project.security_orchestration_policy_configuration.scan_result_policy_reads.last.vulnerability_attributes).to eq({ 'false_positive' => true, 'fix_available' => false })
      end
    end

    context 'with a specific number of rules' do
      using RSpec::Parameterized::TableSyntax

      let(:rule) do
        {
          type: 'scan_finding',
          branches: %w[master],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end

      let(:rules) { [rule] * rules_count }

      let(:policy) { build(:scan_result_policy, name: 'Test Policy', rules: rules) }

      where(:rules_count, :expected_rules_count) do
        [
          [Security::ScanResultPolicy::LIMIT - 1, Security::ScanResultPolicy::LIMIT - 1],
          [Security::ScanResultPolicy::LIMIT, Security::ScanResultPolicy::LIMIT],
          [Security::ScanResultPolicy::LIMIT + 1, Security::ScanResultPolicy::LIMIT]
        ]
      end

      with_them do
        it 'creates approval rules up to limit' do
          subject

          expect(project.approval_rules.count).to be expected_rules_count
        end
      end
    end

    context 'when user does not have edit_approval_rule permission' do
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', actions: [{ type: 'require_approval', approvals_required: 1, user_approvers_ids: [approver.id] }]) }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(approver, :edit_approval_rule, project).and_return(false)
      end

      it_behaves_like 'create approval rule with specific approver'
    end

    context 'with empty branches' do
      let(:rule) do
        {
          type: 'scan_finding',
          branches: [],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end

      let(:rules) { [rule] }
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', rules: rules) }

      before do
        create(:protected_branch, project: project)
      end

      it 'sets applies_to_all_protected_branches to true' do
        subject

        expect(project.approval_rules.first.applies_to_all_protected_branches).to be_truthy
        expect(project.approval_rules.first.applies_to_branch?('random-branch')).to be_falsey
      end
    end

    context 'with branch_type' do
      let(:rules) do
        [{
          type: 'scan_finding',
          branch_type: branch_type,
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }]
      end

      let(:policy) { build(:scan_result_policy, name: 'Test Policy', rules: rules) }

      context 'when protected' do
        let(:branch_type) { 'protected' }

        it 'sets applies_to_all_protected_branches to true' do
          subject

          expect(project.approval_rules.first.applies_to_all_protected_branches).to be_truthy
          expect(project.approval_rules.first.applies_to_branch?('random-branch')).to be_falsey
        end

        context 'with branch exceptions' do
          before do
            rules.first[:branch_exceptions] = %w[main]
          end

          it 'sets applies_to_all_protected_branches to false' do
            subject

            expect(project.approval_rules.first.applies_to_all_protected_branches).to be_falsey
            expect(project.approval_rules.first.applies_to_branch?('main')).to be_falsey
          end

          context 'when branch_exceptions are emtpy' do
            before do
              rules.first[:branch_exceptions] = []
            end

            it 'sets applies_to_all_protected_branches to true' do
              subject

              expect(project.approval_rules.first.applies_to_all_protected_branches).to be_truthy
            end
          end
        end
      end
    end

    context 'with vulnerability_age' do
      let(:rule) do
        {
          type: 'scan_finding',
          branches: %w[master],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected],
          vulnerability_age: { operator: 'greater_than', interval: 'day', value: 1 }
        }
      end

      let(:rules) { [rule] }
      let(:policy) { build(:scan_result_policy, name: 'Test Policy', rules: rules) }

      it 'creates new approval rules' do
        expect { subject }.to change { project.approval_rules.count }.by(1)
      end

      it 'creates scan_result_policy_read' do
        subject

        scan_result_policy_read = project.approval_rules.first.scan_result_policy_read
        expect(scan_result_policy_read.greater_than?).to be_truthy
        expect(scan_result_policy_read.day?).to be_truthy
        expect(scan_result_policy_read.age_value).to eq(1)
      end
    end

    context 'with approval_settings' do
      let(:rule) do
        {
          type: 'scan_finding',
          branches: %w[master],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end

      let(:policy) do
        build(:scan_result_policy, :with_approval_settings, name: 'Test Policy', rules: [rule])
      end

      it 'creates new approval rules' do
        expect { subject }.to change { project.approval_rules.count }.by(1)
      end

      it 'creates scan_result_policy_read' do
        subject

        scan_result_policy_read = project.approval_rules.first.scan_result_policy_read
        expect(scan_result_policy_read.project_approval_settings).to(
          eq policy[:approval_settings].with_indifferent_access
        )
      end
    end

    describe 'rule params `protected_branch_ids`' do
      let(:protected_branch_name) { 'protected-branch-name' }
      let(:rule) do
        {
          type: 'scan_finding',
          branches: [protected_branch_name],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end

      let(:policy) { build(:scan_result_policy, name: 'Test Policy', rules: [rule]) }
      let(:scan_finding_rule) { project.approval_rules.first }

      let!(:project_protected_branch) do
        create(:protected_branch, project: project, name: protected_branch_name)
      end

      let!(:group_protected_branch) do
        create(:protected_branch, project: nil, group: group, name: protected_branch_name)
      end

      before do
        stub_licensed_features(multiple_approval_rules: true)
      end

      context 'when feature flag `group_protected_branches` enabled' do
        include_context 'with existing branch' do
          let(:name) { protected_branch_name }
        end

        before do
          stub_feature_flags(group_protected_branches: true)
          stub_feature_flags(allow_protected_branches_for_group: true)
        end

        it 'set `protected_branch_ids` from the project and group level' do
          subject

          expect(scan_finding_rule.protected_branch_ids).to match_array([
            project_protected_branch.id,
            group_protected_branch.id
          ])
        end
      end

      context 'when feature flag `group_protected_branches` disabled' do
        before do
          stub_feature_flags(group_protected_branches: false)
          stub_feature_flags(allow_protected_branches_for_group: false)
        end

        include_context 'with existing branch' do
          let(:name) { protected_branch_name }
        end

        it 'set `protected_branch_ids` from only the project level' do
          subject

          expect(scan_finding_rule.protected_branch_ids).to match_array([project_protected_branch.id])
        end
      end
    end

    context 'with license_finding rule_type' do
      let(:policy) { build(:scan_result_policy, :license_finding) }

      it 'creates scan_result_policy_read' do
        subject

        scan_result_policy_read = project.approval_rules.first.scan_result_policy_read
        expect(scan_result_policy_read).to eq(Security::ScanResultPolicyRead.first)
        expect(scan_result_policy_read.match_on_inclusion).to be_truthy
        expect(scan_result_policy_read.license_states).to match_array(%w[newly_detected detected])
        expect(scan_result_policy_read.rule_idx).to be(0)
      end

      it 'creates software_license_policies' do
        expect { subject }.to change { project.software_license_policies.count }.by(2)
      end

      it 'creates approval_rules with valid params' do
        subject

        approval_rule = project.approval_rules.first

        expect(approval_rule.severity_levels).to be_empty
      end
    end

    context 'with any_merge_request rule_type' do
      let(:policy) { build(:scan_result_policy, :any_merge_request, commits: 'unsigned') }

      it 'creates new approval rules with provided params' do
        expect { subject }.to change { project.approval_rules.count }.by(1)

        approval_rule = project.approval_rules.first

        expect(approval_rule).to be_any_merge_request
      end

      it 'creates scan_result_policy_read' do
        subject

        scan_result_policy_read = project.approval_rules.first.scan_result_policy_read
        expect(scan_result_policy_read).to eq(Security::ScanResultPolicyRead.first)
        expect(scan_result_policy_read).to be_commits_unsigned
        expect(scan_result_policy_read.rule_idx).to be(0)
      end

      context 'when feature flag "scan_result_any_merge_request" is disabled' do
        before do
          stub_feature_flags(scan_result_any_merge_request: false)
        end

        it "doesn't create new approval rules" do
          expect { subject }.not_to change { project.approval_rules.count }
        end

        it 'creates scan_result_policy_read' do
          expect { subject }.to change { project.scan_result_policy_reads.count }.by(1)

          scan_result_policy_read = project.scan_result_policy_reads.first
          expect(scan_result_policy_read).to be_commits_unsigned
          expect(scan_result_policy_read.rule_idx).to be(0)
        end
      end

      context 'when rule has no actions' do
        let(:policy) { build(:scan_result_policy, :any_merge_request, commits: 'unsigned', actions: []) }

        it 'does not create approval rule' do
          expect { subject }.not_to change { project.approval_rules.count }
        end
      end
    end

    it 'sets project approval rule based on policy', :aggregate_failures do
      subject

      scan_finding_rule = project.approval_rules.first
      first_rule = policy[:rules].first
      first_action = policy[:actions].first

      expect(scan_finding_rule.name).to include(policy[:name])
      expect(scan_finding_rule.report_type).to eq(Security::ScanResultPolicy::SCAN_FINDING)
      expect(scan_finding_rule.rule_type).to eq('report_approver')
      expect(scan_finding_rule.scanners).to eq(first_rule[:scanners])
      expect(scan_finding_rule.severity_levels).to eq(first_rule[:severity_levels])
      expect(scan_finding_rule.vulnerabilities_allowed).to eq(first_rule[:vulnerabilities_allowed])
      expect(scan_finding_rule.vulnerability_states).to eq(first_rule[:vulnerability_states])
      expect(scan_finding_rule.approvals_required).to eq(first_action[:approvals_required])
      expect(scan_finding_rule.security_orchestration_policy_configuration).to eq(policy_configuration)
      expect(scan_finding_rule.orchestration_policy_idx).to eq(0)
    end
  end
end
