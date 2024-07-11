# frozen_string_literal: true

module EE
  module Gitlab
    module EventStore
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override
        # Define event subscriptions using:
        #
        #   store.subscribe(DomainA::SomeWorker, to: DomainB::SomeEvent)
        #
        # It is possible to subscribe to a subset of events matching a condition:
        #
        #   store.subscribe(DomainA::SomeWorker, to: DomainB::SomeEvent), if: ->(event) { event.data == :some_value }
        #
        # Only EE subscriptions should be declared in this module.
        override :configure!
        def configure!(store)
          super(store)

          ###
          # Add EE only subscriptions here:

          store.subscribe ::Security::Scans::PurgeByJobIdWorker, to: ::Ci::JobArtifactsDeletedEvent
          store.subscribe ::Geo::CreateRepositoryUpdatedEventWorker,
            to: ::Repositories::KeepAroundRefsCreatedEvent,
            if: -> (_) { ::Gitlab::Geo.primary? }
          store.subscribe ::MergeRequests::StreamApprovalAuditEventWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::MergeRequests::ProcessApprovalAutoMergeWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::MergeRequests::ProcessApprovalAutoMergeWorker, to: ::MergeRequests::DraftStateChangeEvent
          store.subscribe ::MergeRequests::ProcessApprovalAutoMergeWorker, to: ::MergeRequests::UnblockedStateEvent
          store.subscribe ::PullMirrors::ReenableConfigurationWorker, to: ::GitlabSubscriptions::RenewedEvent
          store.subscribe ::Search::ElasticDefaultBranchChangedWorker,
            to: ::Repositories::DefaultBranchChangedEvent,
            if: -> (_) { ::Gitlab::CurrentSettings.elasticsearch_indexing? }
          store.subscribe ::Search::Zoekt::DefaultBranchChangedWorker, to: ::Repositories::DefaultBranchChangedEvent
          store.subscribe ::PackageMetadata::AdvisoryScanWorker, to: ::PackageMetadata::IngestedAdvisoryEvent
          store.subscribe ::Llm::NamespaceAccessCacheResetWorker, to: ::NamespaceSettings::AiRelatedSettingsChangedEvent
          store.subscribe ::Llm::NamespaceAccessCacheResetWorker, to: ::Members::MembersAddedEvent
          store.subscribe ::Security::RefreshProjectPoliciesWorker,
            to: ::ProjectAuthorizations::AuthorizationsChangedEvent,
            delay: 1.minute
        end
      end
    end
  end
end
