# frozen_string_literal: true

module EE
  module API
    module API
      extend ActiveSupport::Concern

      prepended do
        use ::Gitlab::Middleware::IpRestrictor

        mount ::EE::API::GroupBoards

        mount ::API::Admin::Search::Zoekt
        mount ::API::Admin::Search::Migrations
        mount ::API::Ai::Experimentation::OpenAi
        mount ::API::Ai::Experimentation::VertexAi
        mount ::API::Ai::Experimentation::Anthropic
        mount ::API::AuditEvents
        mount ::API::ProjectApprovalRules
        mount ::API::StatusChecks
        mount ::API::ProjectApprovalSettings
        mount ::API::Dora::Metrics
        mount ::API::EpicIssues
        mount ::API::EpicLinks
        mount ::API::Epics
        mount ::API::EpicBoards
        mount ::API::DependencyProxy::Packages::Maven
        mount ::API::RelatedEpicLinks
        mount ::API::ElasticsearchIndexedNamespaces
        mount ::API::Experiments
        mount ::API::GeoNodes
        mount ::API::GeoSites
        mount ::API::Ldap
        mount ::API::LdapGroupLinks
        mount ::API::License
        mount ::API::ProjectMirror
        mount ::API::ProjectPushRule
        mount ::API::GroupPushRule
        mount ::API::MergeTrains
        mount ::API::MemberRoles
        mount ::API::ProviderIdentity
        mount ::API::GroupHooks
        mount ::API::MergeRequestApprovalSettings
        mount ::API::Scim::GroupScim
        mount ::API::Scim::InstanceScim
        mount ::API::ServiceAccounts
        mount ::API::ManagedLicenses
        mount ::API::ProjectApprovals
        mount ::API::Vulnerabilities
        mount ::API::VulnerabilityFindings
        mount ::API::VulnerabilityIssueLinks
        mount ::API::VulnerabilityExports
        mount ::API::MergeRequestApprovalRules
        mount ::API::ProjectAliases
        mount ::API::Dependencies
        mount ::API::VisualReviewDiscussions
        mount ::API::Analytics::CodeReviewAnalytics
        mount ::API::Analytics::GroupActivityAnalytics
        mount ::API::Analytics::ProductAnalytics
        mount ::API::Analytics::ProjectDeploymentFrequency
        mount ::API::ProtectedEnvironments
        mount ::API::ResourceWeightEvents
        mount ::API::ResourceIterationEvents
        mount ::API::SamlGroupLinks
        mount ::API::Iterations
        mount ::API::GroupRepositoryStorageMoves
        mount ::API::GroupProtectedBranches
        mount ::API::Ci::Minutes
        mount ::API::Ml::AiAssist
        mount ::API::DependencyListExports
        mount ::API::GroupServiceAccounts
        mount ::API::Ai::Llm::GitCommand
        mount ::API::CodeSuggestions
        mount ::API::GitlabSubscriptions::AddOnPurchases

        mount ::API::Internal::AppSec::Dast::SiteValidations
        mount ::API::Internal::Search::Zoekt
        mount ::API::Internal::SuggestedReviewers
        mount ::API::Internal::UpcomingReconciliations
      end
    end
  end
end
