# frozen_string_literal: true
require 'erb'

module QA
  RSpec.describe 'Configure',
    only: { pipeline: %i[staging staging-canary canary production] }, product_group: :environments do
    include Service::Shellout

    describe 'Kubernetes Agent' do
      let!(:project) { create(:project, name: 'kubernetes-app-project') }
      let!(:cluster) { Service::KubernetesCluster.new(provider_class: Service::ClusterProvider::Gcloud).create! }
      let!(:kubernetes_agent) do
        Resource::Clusters::Agent.fabricate_via_api! do |agent|
          agent.name = 'agent1'
          agent.project = project
        end
      end

      let!(:agent_token) do
        Resource::Clusters::AgentToken.fabricate_via_api! do |token|
          token.agent = kubernetes_agent
        end
      end

      before do
        cluster.install_kubernetes_agent(agent_token.token, kubernetes_agent.name)

        creates_agent_config(project)
      end

      after do
        cluster&.remove!

        project.group.remove_via_api!
      end

      it(
        'deploys a K8s manifest file',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347638'
      ) do
        deploy_manifest(project)

        expect(manifest_deployed?).to be_truthy
      end

      private

      def manifest_deployed?
        wait_until_shell_command_matches(
          'kubectl get namespace --no-headers --ignore-not-found galatic-empire',
          /galatic-empire   Active/, sleep_interval: 5
        )
      end

      def read_agent_fixture(file_name)
        File.read(Runtime::Path.fixture('kubernetes_agent', file_name))
      end

      def creates_agent_config(project)
        agent_config_template = read_agent_fixture("agentk-config.yaml.erb")
        agent_config = ERB.new(agent_config_template).result(binding)

        create(:commit, project: project, commit_message: 'Creates agent config', actions: [
          { action: 'create', file_path: '.gitlab/agents/my-agent/config.yaml', content: agent_config }
        ])
      end

      def deploy_manifest(project)
        galatic_empire_manifest = read_agent_fixture("galatic-empire-manifest.yaml")

        create(:commit, project: project, commit_message: 'Deploys the Galactic Empire!', actions: [
          { action: 'create', file_path: 'manifest.yaml', content: galatic_empire_manifest }
        ])
      end
    end
  end
end
