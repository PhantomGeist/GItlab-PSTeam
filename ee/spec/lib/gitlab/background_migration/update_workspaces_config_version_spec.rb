# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::UpdateWorkspacesConfigVersion, feature_category: :remote_development do
  describe "#perform" do
    let(:v1) { RemoteDevelopment::Workspaces::ConfigVersion::VERSION_1 }
    let(:v2) { RemoteDevelopment::Workspaces::ConfigVersion::VERSION_2 }
    let(:personal_access_tokens_table) { table(:personal_access_tokens) }
    let(:pat) do
      personal_access_tokens_table.create!(name: 'workspace1', user_id: user.id, scopes: "---\n- api\n",
        expires_at: 4.days.from_now)
    end

    let(:workspace_attrs) do
      {
        user_id: user.id,
        project_id: project.id,
        cluster_agent_id: cluster_agent.id,
        personal_access_token_id: pat.id,
        desired_state_updated_at: 2.seconds.ago,
        max_hours_before_termination: 19,
        namespace: 'ns',
        desired_state: ::RemoteDevelopment::Workspaces::States::RUNNING,
        editor: 'e',
        devfile_ref: 'dfr',
        devfile_path: 'dev/path',
        url: 'https://www.example.org'
      }
    end

    let(:namespace) { table(:namespaces).create!(name: 'namespace', path: 'namespace') }
    let(:project) do
      table(:projects).create!(name: 'project', path: 'project', project_namespace_id: namespace.id,
        namespace_id: namespace.id)
    end

    let(:cluster_agent) { table(:cluster_agents).create!(name: 'cluster_agent', project_id: project.id) }
    let(:user) { table(:users).create!(email: 'author@example.com', username: 'author', projects_limit: 10) }
    let(:workspaces_table) { table(:workspaces) }
    let!(:workspace_with_config_1_actual_state_terminated) do
      workspaces_table.create!({
        name: 'workspace1',
        config_version: v1,
        actual_state: ::RemoteDevelopment::Workspaces::States::TERMINATED,
        force_include_all_resources: false
      }.merge!(workspace_attrs))
    end

    let!(:workspace_with_config_1_actual_state_running) do
      workspaces_table.create!({
        name: 'workspace2',
        config_version: v1,
        actual_state: ::RemoteDevelopment::Workspaces::States::RUNNING
      }.merge!(workspace_attrs))
    end

    let!(:workspace_with_config_2_actual_state_running) do
      workspaces_table.create!({
        name: 'workspace3',
        config_version: v2,
        actual_state: ::RemoteDevelopment::Workspaces::States::RUNNING,
        force_include_all_resources: false
      }.merge!(workspace_attrs))
    end

    let(:migration) do
      described_class.new(
        start_id: workspace_with_config_1_actual_state_terminated.id,
        end_id: workspace_with_config_2_actual_state_running.id,
        batch_table: :workspaces,
        batch_column: :id,
        sub_batch_size: 2,
        pause_ms: 0,
        connection: ApplicationRecord.connection
      )
    end

    it "updates config_version and force_include_all_resources for existing non-terminated workspaces" do
      migration.perform

      workspace_with_config_1_actual_state_running.reload

      expect(workspace_with_config_1_actual_state_running.config_version).to eq(v2)
      expect(workspace_with_config_1_actual_state_running.force_include_all_resources).to eq(true)
    end

    it "does not update workspaces with different config_version or actual_state" do
      migration.perform

      workspace_with_config_1_actual_state_terminated.reload
      workspace_with_config_2_actual_state_running.reload

      expect(workspace_with_config_1_actual_state_terminated.config_version).to eq(v1)
      expect(workspace_with_config_1_actual_state_terminated.force_include_all_resources).to eq(false)

      expect(workspace_with_config_2_actual_state_running.config_version).to eq(v2)
      expect(workspace_with_config_2_actual_state_running.force_include_all_resources).to eq(false)
    end
  end
end
