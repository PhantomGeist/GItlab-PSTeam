# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TransferService do
  include EE::GeoHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }

  let(:project) { create(:project, :repository, :public, :legacy_storage, namespace: user.namespace) }

  subject { described_class.new(project, user) }

  before do
    group.add_owner(user)
  end

  context 'audit events' do
    include_examples 'audit event logging' do
      let(:fail_condition!) do
        expect(project).to receive(:has_container_registry_tags?).and_return(true)

        def operation
          subject.execute(group)
        end
      end

      let(:attributes) do
        {
           author_id: user.id,
           entity_id: project.id,
           entity_type: 'Project',
           details: {
             change: 'namespace',
             from: project.old_path_with_namespace,
             to: project.full_path,
             author_name: user.name,
             author_class: user.class.name,
             target_id: project.id,
             target_type: 'Project',
             target_details: project.full_path,
             custom_message: "Changed namespace from #{project.old_path_with_namespace} to #{project.full_path}"
           }
         }
      end
    end
  end

  context 'missing epics applied to issues' do
    it 'delegates transfer to Epics::TransferService' do
      expect_next_instance_of(Epics::TransferService, user, project.group, project) do |epics_transfer_service|
        expect(epics_transfer_service).to receive(:execute).once.and_call_original
      end

      subject.execute(group)
    end
  end

  describe 'elasticsearch indexing' do
    it 'delegates transfer to Elastic::ProjectTransferWorker and ::Search::Zoekt::ProjectTransferWorker' do
      expect(::Elastic::ProjectTransferWorker).to receive(:perform_async).with(project.id, project.namespace.id, group.id).once
      expect(::Search::Zoekt::ProjectTransferWorker).to receive(:perform_async).with(project.id, project.namespace.id).once

      subject.execute(group)
    end
  end

  describe 'moving the vulnerability read records to new group', feature_category: :vulnerability_management do
    before do
      allow(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to receive(:perform_async)
    end

    context 'when the project does not have vulnerabilities' do
      it 'does not schedule the update job' do
        subject.execute(group)

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).not_to have_received(:perform_async)
      end
    end

    context 'when the project has vulnerabilities' do
      before do
        create(:project_setting, project: project, has_vulnerabilities: true)
      end

      it 'schedules the update job' do
        subject.execute(group)

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to have_received(:perform_async).with(project.id)
      end
    end
  end

  describe 'security policy project', feature_category: :security_policy_management do
    context 'when project has policy project' do
      let!(:configuration) { create(:security_orchestration_policy_configuration, project: project) }

      it 'unassigns the policy project' do
        subject.execute(group)

        expect { configuration.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end

    context 'when project has inherited policy project' do
      let_it_be(:group, reload: true) { create(:group) }
      let_it_be(:sub_group, reload: true) { create(:group, parent: group) }
      let_it_be(:group_configuration, reload: true) { create(:security_orchestration_policy_configuration, project: nil, namespace: group) }
      let_it_be(:sub_group_configuration, reload: true) { create(:security_orchestration_policy_configuration, project: nil, namespace: sub_group) }

      let!(:group_approval_rule) { create(:approval_project_rule, :scan_finding, :requires_approval, project: project, security_orchestration_policy_configuration: group_configuration) }
      let!(:sub_group_approval_rule) { create(:approval_project_rule, :scan_finding, :requires_approval, project: project, security_orchestration_policy_configuration: sub_group_configuration) }

      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      context 'when transferring the project within the same hierarchy' do
        before do
          sub_group.add_owner(user)
        end

        it 'deletes scan_finding_rules for inherited policy project' do
          subject.execute(sub_group)

          expect(project.approval_rules).to be_empty
          expect { group_approval_rule.reload }.to raise_exception(ActiveRecord::RecordNotFound)
          expect { sub_group_approval_rule.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        end
      end

      context 'when transferring the project from one hierarchy to another' do
        let(:project) { create(:project, :repository, group: sub_group) }

        let_it_be(:other_group, reload: true) { create(:group) }

        before do
          other_group.add_owner(user)
        end

        it 'deletes scan_finding_rules for inherited policy project' do
          subject.execute(other_group)

          expect(project.approval_rules).to be_empty
          expect { group_approval_rule.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        end

        it 'triggers Security::ScanResultPolicies::SyncProjectWorker to sync new group policies' do
          expect(Security::ScanResultPolicies::SyncProjectWorker).to receive(:perform_async).with(project.id)

          subject.execute(other_group)
        end
      end
    end
  end

  describe 'updating paid features' do
    let(:premium_group) { create(:group_with_plan, plan: :premium_plan) }

    let_it_be(:free_group) { create(:group) }

    before do
      free_group.add_owner(user)
    end

    describe 'project access tokens' do
      before do
        ResourceAccessTokens::CreateService.new(user, project).execute
      end

      def revoked_tokens
        PersonalAccessToken.without_impersonation.for_users(project.bots).revoked
      end

      context 'with a self managed instance' do
        before do
          stub_ee_application_setting(should_check_namespace_plan: false)
        end

        it 'does not revoke PATs' do
          subject.execute(group)

          expect { subject.execute(group) }.not_to change { revoked_tokens.count }
        end
      end

      context 'with GL.com', :saas do
        before do
          premium_group.add_owner(user)
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        context 'when target namespace has a premium plan' do
          it 'does not revoke PATs' do
            expect { subject.execute(premium_group) }.not_to change { revoked_tokens.count }
          end
        end

        context 'when target namespace has a free plan' do
          it 'revoke PATs' do
            expect { subject.execute(free_group) }.to change { revoked_tokens.count }.from(0).to(1)
          end
        end
      end
    end

    describe 'pipeline subscriptions', :saas do
      let_it_be(:project_2) { create(:project, :public) }

      before do
        create(:license, plan: License::PREMIUM_PLAN)
        stub_ee_application_setting(should_check_namespace_plan: true)

        premium_group.add_owner(user)
      end

      context 'when target namespace has a premium plan' do
        it 'does not schedule cleanup for upstream project subscription' do
          expect(::Ci::UpstreamProjectsSubscriptionsCleanupWorker).not_to receive(:perform_async)

          subject.execute(premium_group)
        end
      end

      context 'when target namespace has a free plan' do
        it 'schedules cleanup for upstream project subscription' do
          expect(::Ci::UpstreamProjectsSubscriptionsCleanupWorker).to receive(:perform_async).with(project.id).and_call_original

          subject.execute(free_group)
        end
      end
    end

    describe 'test cases', :saas do
      before do
        create(:quality_test_case, project: project, author: user)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'when target namespace has a premium plan' do
        it 'does not delete the test cases' do
          subject.execute(premium_group)

          expect { subject.execute(premium_group) }.not_to change { project.issues.with_issue_type(:test_case).count }
        end
      end

      context 'when target namespace has a free plan' do
        it 'deletes the test cases' do
          expect { subject.execute(free_group) }.to change { project.issues.with_issue_type(:test_case).count }.from(1).to(0)
        end
      end
    end
  end

  describe 'deleting compliance framework setting' do
    context 'when the project has a compliance framework setting' do
      let!(:compliance_framework_setting) { create(:compliance_framework_project_setting, project: project) }

      it 'deletes the compliance framework setting' do
        expect { subject.execute(group) }.to change { ::ComplianceManagement::ComplianceFramework::ProjectSettings.count }.from(1).to(0)
      end
    end

    context 'when the project does not have a compliance framework setting' do
      it 'does not raise an error' do
        expect { subject.execute(group) }.not_to raise_error
      end

      it 'does not change the compliance framework settings count' do
        expect { subject.execute(group) }.not_to change { ::ComplianceManagement::ComplianceFramework::ProjectSettings.count }
      end
    end
  end

  context 'update_compliance_standards_adherence' do
    let_it_be(:old_group) { create(:group) }
    let_it_be(:project) { create(:project, group: old_group) }
    let!(:adherence) { create(:compliance_standards_adherence, :gitlab, project: project) }

    before do
      stub_licensed_features(group_level_compliance_dashboard: true)
      old_group.add_owner(user)
    end

    it "updates the project's compliance standards adherence with new namespace id" do
      expect(project.compliance_standards_adherence.first.namespace_id).to eq(old_group.id)

      subject.execute(group)

      expect(project.reload.compliance_standards_adherence.first.namespace_id).to eq(group.id)
    end
  end
end
