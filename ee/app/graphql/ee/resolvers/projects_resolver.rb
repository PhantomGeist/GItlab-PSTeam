# frozen_string_literal: true

module EE
  module Resolvers
    module ProjectsResolver
      extend ::Gitlab::Utils::Override

      private

      override :preloads
      def preloads
        super.merge(
          has_jira_vulnerability_issue_creation_enabled: [:jira_imports, :jira_integration],
          merge_requests_disable_committers_approval: [{ group: :group_merge_request_approval_setting }]
        )
      end
    end
  end
end
