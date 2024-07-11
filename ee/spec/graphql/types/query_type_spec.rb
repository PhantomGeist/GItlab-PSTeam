# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Query'], feature_category: :shared do
  include_context 'with FOSS query type fields'

  specify do
    expected_ee_fields = [
      :ai_messages,
      :ci_catalog_resources,
      :ci_catalog_resource,
      :ci_minutes_usage,
      :ci_queueing_history,
      :current_license,
      :devops_adoption_enabled_namespaces,
      :epic_board_list,
      :explain_vulnerability_prompt,
      :geo_node,
      :instance_security_dashboard,
      :iteration,
      :license_history_entries,
      :member_role_permissions,
      :organization,
      :subscription_future_entries,
      :vulnerabilities,
      :vulnerabilities_count_by_day,
      :vulnerability,
      :workspace,
      :workspaces,
      :instance_external_audit_event_destinations,
      :instance_google_cloud_logging_configurations
    ]

    all_expected_fields = expected_foss_fields + expected_ee_fields

    expect(described_class).to have_graphql_fields(*all_expected_fields)
  end

  describe 'epicBoardList field' do
    subject { described_class.fields['epicBoardList'] }

    it 'finds an epic board list by its gid' do
      is_expected.to have_graphql_arguments(:id, :epic_filters)
      is_expected.to have_graphql_type(Types::Boards::EpicListType)
      is_expected.to have_graphql_resolver(Resolvers::Boards::EpicListResolver)
    end
  end
end
