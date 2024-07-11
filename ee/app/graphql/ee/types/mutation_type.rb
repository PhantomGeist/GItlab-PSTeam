# frozen_string_literal: true

module EE
  module Types
    module MutationType
      extend ActiveSupport::Concern

      prepended do
        mount_mutation ::Mutations::Ci::Ai::GenerateConfig, alpha: { milestone: '16.0' }
        mount_mutation ::Mutations::Ci::ProjectSubscriptions::Create
        mount_mutation ::Mutations::Ci::ProjectSubscriptions::Delete
        mount_mutation ::Mutations::ComplianceManagement::Frameworks::Destroy
        mount_mutation ::Mutations::ComplianceManagement::Frameworks::Update
        mount_mutation ::Mutations::ComplianceManagement::Frameworks::Create
        mount_mutation ::Mutations::Issues::SetIteration
        mount_mutation ::Mutations::Issues::SetWeight
        mount_mutation ::Mutations::Issues::SetEpic
        mount_mutation ::Mutations::Issues::SetEscalationPolicy
        mount_mutation ::Mutations::Issues::PromoteToEpic
        mount_mutation ::Mutations::EpicTree::Reorder
        mount_mutation ::Mutations::Epics::Update
        mount_mutation ::Mutations::Epics::Create
        mount_mutation ::Mutations::Epics::SetSubscription
        mount_mutation ::Mutations::Epics::AddIssue
        mount_mutation ::Mutations::Geo::Registries::Update, alpha: { milestone: '16.1' }
        mount_mutation ::Mutations::Geo::Registries::BulkUpdate, alpha: { milestone: '16.4' }
        mount_mutation ::Mutations::GitlabSubscriptions::Activate
        mount_mutation ::Mutations::GitlabSubscriptions::UserAddOnAssignments::Create, alpha: { milestone: '16.3' }
        mount_mutation ::Mutations::GitlabSubscriptions::UserAddOnAssignments::Remove, alpha: { milestone: '16.3' }
        mount_mutation ::Mutations::Projects::SetLocked
        mount_mutation ::Mutations::Iterations::Create
        mount_mutation ::Mutations::Iterations::Update
        mount_mutation ::Mutations::Iterations::Delete
        mount_mutation ::Mutations::Iterations::Cadences::Create
        mount_mutation ::Mutations::Iterations::Cadences::Update
        mount_mutation ::Mutations::Iterations::Cadences::Destroy
        mount_mutation ::Mutations::MemberRoles::Update
        mount_mutation ::Mutations::MemberRoles::Create, alpha: { milestone: '16.5' }
        mount_mutation ::Mutations::RequirementsManagement::CreateRequirement
        mount_mutation ::Mutations::RequirementsManagement::ExportRequirements
        mount_mutation ::Mutations::RequirementsManagement::UpdateRequirement
        mount_mutation ::Mutations::Security::Finding::CreateIssue
        mount_mutation ::Mutations::Security::Finding::CreateMergeRequest
        mount_mutation ::Mutations::Security::Finding::Dismiss
        mount_mutation ::Mutations::Security::Finding::RevertToDetected
        mount_mutation ::Mutations::Vulnerabilities::Create
        mount_mutation ::Mutations::Vulnerabilities::BulkDismiss
        mount_mutation ::Mutations::Vulnerabilities::Dismiss
        mount_mutation ::Mutations::Vulnerabilities::Resolve
        mount_mutation ::Mutations::Vulnerabilities::Confirm
        mount_mutation ::Mutations::Vulnerabilities::RevertToDetected
        mount_mutation ::Mutations::Vulnerabilities::CreateIssueLink
        mount_mutation ::Mutations::Vulnerabilities::CreateExternalIssueLink
        mount_mutation ::Mutations::Vulnerabilities::DestroyExternalIssueLink
        mount_mutation ::Mutations::Boards::UpdateEpicUserPreferences
        mount_mutation ::Mutations::Boards::EpicBoards::Create
        mount_mutation ::Mutations::Boards::EpicBoards::Destroy
        mount_mutation ::Mutations::Boards::EpicBoards::EpicMoveList
        mount_mutation ::Mutations::Boards::EpicBoards::Update
        mount_mutation ::Mutations::Boards::EpicLists::Create
        mount_mutation ::Mutations::Boards::EpicLists::Destroy
        mount_mutation ::Mutations::Boards::EpicLists::Update
        mount_mutation ::Mutations::Boards::Epics::Create
        mount_mutation ::Mutations::Boards::Lists::UpdateLimitMetrics
        mount_mutation ::Mutations::InstanceSecurityDashboard::AddProject
        mount_mutation ::Mutations::InstanceSecurityDashboard::RemoveProject
        mount_mutation ::Mutations::DastOnDemandScans::Create
        mount_mutation ::Mutations::Dast::Profiles::Create
        mount_mutation ::Mutations::Dast::Profiles::Update
        mount_mutation ::Mutations::Dast::Profiles::Delete
        mount_mutation ::Mutations::Dast::Profiles::Run
        mount_mutation ::Mutations::DastSiteProfiles::Create
        mount_mutation ::Mutations::DastSiteProfiles::Update
        mount_mutation ::Mutations::DastSiteProfiles::Delete
        mount_mutation ::Mutations::DastSiteValidations::Create
        mount_mutation ::Mutations::DastSiteValidations::Revoke
        mount_mutation ::Mutations::DastScannerProfiles::Create
        mount_mutation ::Mutations::DastScannerProfiles::Update
        mount_mutation ::Mutations::DastScannerProfiles::Delete
        mount_mutation ::Mutations::DastSiteTokens::Create
        mount_mutation ::Mutations::Namespaces::IncreaseStorageTemporarily
        mount_mutation ::Mutations::QualityManagement::TestCases::Create
        mount_mutation ::Mutations::Analytics::DevopsAdoption::EnabledNamespaces::Enable
        mount_mutation ::Mutations::Analytics::DevopsAdoption::EnabledNamespaces::BulkEnable
        mount_mutation ::Mutations::Analytics::DevopsAdoption::EnabledNamespaces::Disable
        mount_mutation ::Mutations::IncidentManagement::OncallSchedule::Create
        mount_mutation ::Mutations::IncidentManagement::OncallSchedule::Update
        mount_mutation ::Mutations::IncidentManagement::OncallSchedule::Destroy
        mount_mutation ::Mutations::IncidentManagement::OncallRotation::Create
        mount_mutation ::Mutations::IncidentManagement::OncallRotation::Update
        mount_mutation ::Mutations::IncidentManagement::OncallRotation::Destroy
        mount_mutation ::Mutations::IncidentManagement::EscalationPolicy::Create
        mount_mutation ::Mutations::IncidentManagement::EscalationPolicy::Update
        mount_mutation ::Mutations::IncidentManagement::EscalationPolicy::Destroy
        mount_mutation ::Mutations::IncidentManagement::IssuableResourceLink::Create
        mount_mutation ::Mutations::IncidentManagement::IssuableResourceLink::Destroy
        mount_mutation ::Mutations::AppSec::Fuzzing::Coverage::Corpus::Create
        mount_mutation ::Mutations::Projects::SetComplianceFramework
        mount_mutation ::Mutations::Projects::InitializeProductAnalytics
        mount_mutation ::Mutations::SecurityPolicy::CommitScanExecutionPolicy
        mount_mutation ::Mutations::SecurityPolicy::AssignSecurityPolicyProject
        mount_mutation ::Mutations::SecurityPolicy::UnassignSecurityPolicyProject
        mount_mutation ::Mutations::SecurityPolicy::CreateSecurityPolicyProject
        mount_mutation ::Mutations::Security::CiConfiguration::ConfigureDependencyScanning
        mount_mutation ::Mutations::Security::CiConfiguration::ConfigureContainerScanning
        mount_mutation ::Mutations::Security::TrainingProviderUpdate
        mount_mutation ::Mutations::Users::Abuse::NamespaceBans::Destroy
        mount_mutation ::Mutations::AuditEvents::ExternalAuditEventDestinations::Create
        mount_mutation ::Mutations::AuditEvents::ExternalAuditEventDestinations::Destroy
        mount_mutation ::Mutations::AuditEvents::ExternalAuditEventDestinations::Update
        mount_mutation ::Mutations::Ci::NamespaceCiCdSettingsUpdate
        mount_mutation ::Mutations::RemoteDevelopment::Workspaces::Create, alpha: { milestone: '16.0' }
        mount_mutation ::Mutations::RemoteDevelopment::Workspaces::Update, alpha: { milestone: '16.0' }
        mount_mutation ::Mutations::AuditEvents::Streaming::Headers::Destroy
        mount_mutation ::Mutations::AuditEvents::Streaming::Headers::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::Headers::Update
        mount_mutation ::Mutations::AuditEvents::Streaming::EventTypeFilters::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::EventTypeFilters::Destroy
        mount_mutation ::Mutations::Deployments::DeploymentApprove
        mount_mutation ::Mutations::MergeRequests::UpdateApprovalRule
        mount_mutation ::Mutations::Ai::Action, alpha: { milestone: '15.11' }
        mount_mutation ::Mutations::AuditEvents::InstanceExternalAuditEventDestinations::Create
        mount_mutation ::Mutations::AuditEvents::InstanceExternalAuditEventDestinations::Destroy
        mount_mutation ::Mutations::AuditEvents::InstanceExternalAuditEventDestinations::Update
        mount_mutation ::Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Create
        mount_mutation ::Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Destroy
        mount_mutation ::Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Update
        mount_mutation ::Mutations::AuditEvents::AmazonS3Configurations::Create
        mount_mutation ::Mutations::AuditEvents::AmazonS3Configurations::Delete
        mount_mutation ::Mutations::AuditEvents::AmazonS3Configurations::Update
        mount_mutation ::Mutations::AuditEvents::Instance::GoogleCloudLoggingConfigurations::Create
        mount_mutation ::Mutations::Forecasting::BuildForecast, alpha: { milestone: '16.0' }
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceHeaders::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceHeaders::Update
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceHeaders::Destroy
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceEventTypeFilters::Create
        mount_mutation ::Mutations::AuditEvents::Streaming::InstanceEventTypeFilters::Destroy
        mount_mutation ::Mutations::Security::CiConfiguration::ProjectSetContinuousVulnerabilityScanning
        mount_mutation ::Mutations::AuditEvents::Instance::GoogleCloudLoggingConfigurations::Destroy
        mount_mutation ::Mutations::AuditEvents::Instance::GoogleCloudLoggingConfigurations::Update
        mount_mutation ::Mutations::DependencyProxy::Packages::Settings::Update, alpha: { milestone: '16.5' }
        mount_mutation ::Mutations::Analytics::CycleAnalytics::ValueStreams::Create, alpha: { milestone: '16.6' }
        mount_mutation ::Mutations::Analytics::CycleAnalytics::ValueStreams::Destroy, alpha: { milestone: '16.6' }

        prepend(Types::DeprecatedMutations)
      end
    end
  end
end
