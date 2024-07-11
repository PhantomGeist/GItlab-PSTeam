# frozen_string_literal: true

module EE
  module Types
    module QueryType
      extend ActiveSupport::Concern
      prepended do
        field :ci_minutes_usage, ::Types::Ci::Minutes::NamespaceMonthlyUsageType.connection_type,
          null: true,
          description: 'Compute usage data for a namespace.' do
          argument :namespace_id, ::Types::GlobalIDType[::Namespace],
            required: false,
            description: 'Global ID of the Namespace for the monthly compute usage.'
          argument :date, ::Types::DateType,
            required: false,
            description: 'Date for which to retrieve the usage data, should be the first day of a month.'
        end
        field :current_license, ::Types::Admin::CloudLicenses::CurrentLicenseType,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::CurrentLicenseResolver,
          description: 'Fields related to the current license.'
        field :devops_adoption_enabled_namespaces,
          null: true,
          description: 'Get configured DevOps adoption namespaces. **BETA** This endpoint is subject to change ' \
                       'without notice.',
          resolver: ::Resolvers::Analytics::DevopsAdoption::EnabledNamespacesResolver
        field :epic_board_list, ::Types::Boards::EpicListType,
          null: true,
          resolver: ::Resolvers::Boards::EpicListResolver
        field :explain_vulnerability_prompt,
          ::Types::Ai::Prompt::ExplainVulnerabilityPromptType,
          null: true,
          calls_gitaly: true,
          alpha: { milestone: '16.2' },
          description: "GitLab Duo Vulnerability summary prompt for a specified vulnerability",
          resolver: ::Resolvers::Ai::ExplainVulnerabilityPromptResolver
        field :geo_node, ::Types::Geo::GeoNodeType,
          null: true,
          resolver: ::Resolvers::Geo::GeoNodeResolver,
          description: 'Find a Geo node.'
        field :iteration, ::Types::IterationType,
          null: true,
          description: 'Find an iteration.' do
          argument :id, ::Types::GlobalIDType[::Iteration],
            required: true,
            description: 'Find an iteration by its ID.'
        end
        field :instance_security_dashboard, ::Types::InstanceSecurityDashboardType,
          null: true,
          resolver: ::Resolvers::InstanceSecurityDashboardResolver,
          description: 'Fields related to Instance Security Dashboard.'
        field :license_history_entries, ::Types::Admin::CloudLicenses::LicenseHistoryEntryType.connection_type,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::LicenseHistoryEntriesResolver,
          description: 'Fields related to entries in the license history.'
        field :subscription_future_entries, ::Types::Admin::CloudLicenses::SubscriptionFutureEntryType.connection_type,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::SubscriptionFutureEntriesResolver,
          description: 'Fields related to entries in future subscriptions.'
        field :vulnerabilities,
          ::Types::VulnerabilityType.connection_type,
          null: true,
          extras: [:lookahead],
          description: "Vulnerabilities reported on projects on the current user's instance security dashboard.",
          resolver: ::Resolvers::VulnerabilitiesResolver
        field :vulnerabilities_count_by_day,
          ::Types::VulnerabilitiesCountByDayType.connection_type,
          null: true,
          resolver: ::Resolvers::VulnerabilitiesCountPerDayResolver,
          description: "The historical number of vulnerabilities per day for the projects on the current " \
                       "user's instance security dashboard."
        field :vulnerability,
          ::Types::VulnerabilityType,
          null: true,
          description: "Find a vulnerability." do
          argument :id, ::Types::GlobalIDType[::Vulnerability],
            required: true,
            description: 'Global ID of the Vulnerability.'
        end
        field :workspace, ::Types::RemoteDevelopment::WorkspaceType,
          null: true,
          alpha: { milestone: '16.0' },
          description: 'Find a workspace.' do
          argument :id, ::Types::GlobalIDType[::RemoteDevelopment::Workspace],
            required: true,
            description: 'Find a workspace by its ID.'
        end
        field :workspaces,
          ::Types::RemoteDevelopment::WorkspaceType.connection_type,
          null: true,
          alpha: { milestone: '16.0' },
          resolver: ::Resolvers::RemoteDevelopment::WorkspacesResolver,
          description: 'Find workspaces owned by the current user by their IDs.'

        field :instance_external_audit_event_destinations,
          ::Types::AuditEvents::InstanceExternalAuditEventDestinationType.connection_type,
          null: true,
          description: 'Instance level external audit event destinations.',
          resolver: ::Resolvers::AuditEvents::InstanceExternalAuditEventDestinationsResolver

        field :ai_messages, ::Types::Ai::MessageType.connection_type,
          resolver: ::Resolvers::Ai::ChatMessagesResolver,
          alpha: { milestone: '16.1' },
          description: 'Find GitLab Duo Chat messages.'

        field :ci_queueing_history,
          ::Types::Ci::QueueingHistoryType,
          null: true,
          alpha: { milestone: '16.4' },
          description: 'Time it took for ci job to be picked up by runner in percentiles.',
          resolver: ::Resolvers::Ci::QueueingHistoryResolver,
          extras: [:lookahead]

        field :instance_google_cloud_logging_configurations,
          ::Types::AuditEvents::Instance::GoogleCloudLoggingConfigurationType.connection_type,
          null: true,
          description: 'Instance level google cloud logging configurations.',
          resolver: ::Resolvers::AuditEvents::Instance::GoogleCloudLoggingConfigurationsResolver
        field :member_role_permissions,
          ::Types::MemberRoles::CustomizablePermissionType.connection_type,
          resolver: ::Resolvers::MemberRoles::PermissionListResolver,
          null: true,
          description: 'List of all customizable permissions.'
      end

      def vulnerability(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def iteration(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def workspace(id:)
        unless ::Feature.enabled?(:remote_development_feature_flag)
          # NOTE: Could have `included Gitlab::Graphql::Authorize::AuthorizeResource` and then use
          #       raise_resource_not_available_error!, but didn't want to take the risk to mix that into
          #       the root query type
          # rubocop:disable Graphql/ResourceNotAvailableError -- intentionally not used - see note above
          raise ::Gitlab::Graphql::Errors::ResourceNotAvailable,
            "'remote_development_feature_flag' feature flag is disabled"
          # rubocop:enable Graphql/ResourceNotAvailableError
        end

        unless License.feature_available?(:remote_development)
          # NOTE: Could have `included Gitlab::Graphql::Authorize::AuthorizeResource` and then use
          #       raise_resource_not_available_error!, but didn't want to take the risk to mix that into
          #       the root query type
          # rubocop:disable Graphql/ResourceNotAvailableError -- intentionally not used - see note above
          raise ::Gitlab::Graphql::Errors::ResourceNotAvailable,
            "'remote_development' licensed feature is not available"
          # rubocop:enable Graphql/ResourceNotAvailableError
        end

        ::GitlabSchema.find_by_gid(id)
      end

      def ci_minutes_usage(namespace_id: nil, date: nil)
        root_namespace = find_root_namespace(namespace_id)
        if date
          ::Ci::Minutes::NamespaceMonthlyUsage.by_namespace_and_date(root_namespace, date)
        else
          ::Ci::Minutes::NamespaceMonthlyUsage.for_namespace(root_namespace)
        end
      end

      private

      def find_root_namespace(namespace_id)
        return current_user&.namespace unless namespace_id

        namespace = ::Gitlab::Graphql::Lazy.force(::GitlabSchema.find_by_gid(namespace_id))
        return unless namespace&.root?

        namespace
      end
    end
  end
end
