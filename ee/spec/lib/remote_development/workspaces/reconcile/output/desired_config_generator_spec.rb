# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::Workspaces::Reconcile::Output::DesiredConfigGenerator, :freeze_time, feature_category: :remote_development do
  include_context 'with remote development shared fixtures'

  describe '#generate_desired_config' do
    let(:logger) { instance_double(Logger) }
    let(:user) { create(:user) }
    let(:agent) { create(:ee_cluster_agent, :with_remote_development_agent_config) }
    let(:desired_state) { RemoteDevelopment::Workspaces::States::RUNNING }
    let(:actual_state) { RemoteDevelopment::Workspaces::States::STOPPED }
    let(:started) { true }
    let(:include_all_resources) { false }
    let(:deployment_resource_version_from_agent) { workspace.deployment_resource_version }
    let(:network_policy_enabled) { true }
    let(:gitlab_workspaces_proxy_namespace) { 'gitlab-workspaces' }

    let(:workspace) do
      create(
        :workspace,
        agent: agent,
        user: user,
        desired_state: desired_state,
        actual_state: actual_state
      )
    end

    let(:expected_config) do
      YAML.load_stream(
        create_config_to_apply(
          workspace: workspace,
          started: started,
          include_network_policy: network_policy_enabled,
          include_all_resources: include_all_resources
        )
      )
    end

    subject do
      described_class
    end

    before do
      allow(agent.remote_development_agent_config)
        .to receive(:network_policy_enabled).and_return(network_policy_enabled)
    end

    context 'when desired_state results in started=true' do
      it 'returns expected config' do
        workspace_resources = subject.generate_desired_config(
          workspace: workspace,
          include_all_resources: include_all_resources,
          logger: logger
        )

        expect(workspace_resources).to eq(expected_config)
      end
    end

    context 'when desired_state results in started=false' do
      let(:desired_state) { RemoteDevelopment::Workspaces::States::STOPPED }
      let(:started) { false }

      it 'returns expected config' do
        workspace_resources = subject.generate_desired_config(
          workspace: workspace,
          include_all_resources: include_all_resources,
          logger: logger
        )

        expect(workspace_resources).to eq(expected_config)
      end
    end

    context 'when network policy is disabled for agent' do
      let(:network_policy_enabled) { false }

      it 'returns expected config without network policy' do
        workspace_resources = subject.generate_desired_config(
          workspace: workspace,
          include_all_resources: include_all_resources,
          logger: logger
        )

        expect(workspace_resources).to eq(expected_config)
      end
    end

    context 'when include_all_resources is true' do
      let(:include_all_resources) { true }

      it 'returns expected config' do
        workspace_resources = subject.generate_desired_config(
          workspace: workspace,
          include_all_resources: include_all_resources,
          logger: logger
        )

        expect(workspace_resources).to eq(expected_config)
      end
    end

    context 'when DevfileParser returns empty array' do
      before do
        allow(RemoteDevelopment::Workspaces::Reconcile::Output::DevfileParser).to receive(:get_all).and_return([])
      end

      it 'returns an empty array' do
        workspace_resources = subject.generate_desired_config(
          workspace: workspace,
          include_all_resources: include_all_resources,
          logger: logger
        )

        expect(workspace_resources).to eq([])
      end
    end
  end
end
