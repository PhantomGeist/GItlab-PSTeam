# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Reconcile
      module Output
        # rubocop:disable Layout/LineLength
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        # noinspection RubyClassMethodNamingConvention,RubyLocalVariableNamingConvention,RubyParameterNamingConvention - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
        # rubocop:enable Layout/LineLength
        class DesiredConfigGenerator
          include States

          # @param [RemoteDevelopment::Workspaces::Workspace] workspace
          # @param [Boolean] include_all_resources
          # @param [RemoteDevelopment::Logger] logger
          # @return [Array<Hash>]
          def self.generate_desired_config(workspace:, include_all_resources:, logger:)
            desired_config = []
            env_secret_name = "#{workspace.name}-env-var"
            file_secret_name = "#{workspace.name}-file"
            env_secret_names = [env_secret_name]
            file_secret_names = [file_secret_name]
            replicas = get_workspace_replicas(desired_state: workspace.desired_state)
            domain_template = get_domain_template_annotation(name: workspace.name, dns_zone: workspace.dns_zone)
            inventory_name = "#{workspace.name}-workspace-inventory"
            labels, annotations = get_labels_and_annotations(
              agent_id: workspace.agent.id,
              domain_template: domain_template,
              owning_inventory: inventory_name,
              workspace_id: workspace.id
            )

            k8s_inventory_for_workspace_core = get_inventory_config_map(
              name: inventory_name,
              namespace: workspace.namespace,
              agent_id: workspace.agent.id
            )

            # TODO: https://gitlab.com/groups/gitlab-org/-/epics/10461 - handle error
            k8s_resources_for_workspace_core = DevfileParser.get_all(
              processed_devfile: workspace.processed_devfile,
              name: workspace.name,
              namespace: workspace.namespace,
              replicas: replicas,
              domain_template: domain_template,
              labels: labels,
              annotations: annotations,
              env_secret_names: env_secret_names,
              file_secret_names: file_secret_names,
              logger: logger
            )
            # If we got no resources back from the devfile parser, this indicates some error was encountered in parsing
            # the processed_devfile. So we return an empty array which will result in no updates being applied by the
            # agent. We should not continue on and try to add anything else to the resources, as this would result
            # in an invalid configuration being applied to the cluster.
            return [] if k8s_resources_for_workspace_core.empty?

            desired_config.append(k8s_inventory_for_workspace_core, *k8s_resources_for_workspace_core)

            remote_development_agent_config = workspace.agent.remote_development_agent_config
            if remote_development_agent_config.network_policy_enabled
              gitlab_workspaces_proxy_namespace = remote_development_agent_config.gitlab_workspaces_proxy_namespace
              network_policy = get_network_policy(
                name: workspace.name,
                namespace: workspace.namespace,
                labels: labels,
                annotations: annotations,
                gitlab_workspaces_proxy_namespace: gitlab_workspaces_proxy_namespace
              )
              desired_config.append(network_policy)
            end

            if include_all_resources
              k8s_resources_for_secrets = get_k8s_resources_for_secrets(
                workspace: workspace,
                env_secret_name: env_secret_name,
                file_secret_name: file_secret_name
              )
              desired_config.append(*k8s_resources_for_secrets)
            end

            desired_config
          end

          # @param [RemoteDevelopment::Workspaces::Workspace] workspace
          # @param [String] env_secret_name
          # @param [String] file_secret_name
          # @param [String] env_secret_name
          # @param [String] file_secret_name
          # @return [Array<(Hash)>]
          def self.get_k8s_resources_for_secrets(workspace:, env_secret_name:, file_secret_name:)
            inventory_name = "#{workspace.name}-secrets-inventory"
            domain_template = get_domain_template_annotation(name: workspace.name, dns_zone: workspace.dns_zone)
            labels, annotations = get_labels_and_annotations(
              agent_id: workspace.agent.id,
              domain_template: domain_template,
              owning_inventory: inventory_name,
              workspace_id: workspace.id
            )

            k8s_inventory = get_inventory_config_map(
              name: inventory_name,
              namespace: workspace.namespace,
              agent_id: workspace.agent.id
            )

            data_for_env_var = workspace.workspace_variables.with_variable_type_env_var
            data_for_env_var = data_for_env_var.each_with_object({}) do |workspace_variable, hash|
              hash[workspace_variable.key] = workspace_variable.value
            end
            k8s_secret_for_env_var = get_secret(
              name: env_secret_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: annotations,
              data: data_for_env_var
            )

            data_for_file = workspace.workspace_variables.with_variable_type_file
            data_for_file = data_for_file.each_with_object({}) do |workspace_variable, hash|
              hash[workspace_variable.key] = workspace_variable.value
            end
            k8s_secret_for_file = get_secret(
              name: file_secret_name,
              namespace: workspace.namespace,
              labels: labels,
              annotations: annotations,
              data: data_for_file
            )

            [k8s_inventory, k8s_secret_for_env_var, k8s_secret_for_file]
          end

          # @param [String] desired_state
          # @return [Integer]
          def self.get_workspace_replicas(desired_state:)
            return 1 if [
              CREATION_REQUESTED,
              RUNNING
            ].include?(desired_state)

            0
          end

          # @param [String] name
          # @param [String] namespace
          # @param [Integer] agent_id
          # @return [Hash]
          def self.get_inventory_config_map(name:, namespace:, agent_id:)
            {
              kind: 'ConfigMap',
              apiVersion: 'v1',
              metadata: {
                name: name,
                namespace: namespace,
                labels: {
                  'cli-utils.sigs.k8s.io/inventory-id': name,
                  'agent.gitlab.com/id': agent_id.to_s
                }
              }
            }.deep_stringify_keys.to_h
          end

          # @param [Integer] agent_id
          # @param [String] domain_template
          # @param [String] owning_inventory
          # @param [String] object_type
          # @param [Integer] workspace_id
          # @return [Array<Hash, Hash>]
          def self.get_labels_and_annotations(
            agent_id:,
            domain_template:,
            owning_inventory:,
            workspace_id:
          )
            labels = {
              'agent.gitlab.com/id' => agent_id.to_s
            }
            annotations = {
              'config.k8s.io/owning-inventory' => owning_inventory.to_s,
              'workspaces.gitlab.com/host-template' => domain_template.to_s,
              'workspaces.gitlab.com/id' => workspace_id.to_s
            }
            [labels, annotations]
          end

          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Hash] data
          # @return [Hash]
          def self.get_secret(name:, namespace:, labels:, annotations:, data:)
            {
              kind: 'Secret',
              apiVersion: 'v1',
              metadata: {
                name: name,
                namespace: namespace,
                labels: labels,
                annotations: annotations
              },
              data: data.transform_values { |v| Base64.strict_encode64(v) }
            }.deep_stringify_keys.to_h
          end

          # @param [String] name
          # @param [String] dns_zone
          # @return [String]
          def self.get_domain_template_annotation(name:, dns_zone:)
            "{{.port}}-#{name}.#{dns_zone}"
          end

          # @param [String] name
          # @param [String] namespace
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [string] gitlab_workspaces_proxy_namespace
          # @return [Hash]
          def self.get_network_policy(name:, namespace:, labels:, annotations:, gitlab_workspaces_proxy_namespace:)
            policy_types = [
              - "Ingress",
              - "Egress"
            ]

            proxy_namespace_selector = {
              matchLabels: {
                "kubernetes.io/metadata.name": gitlab_workspaces_proxy_namespace
              }
            }
            proxy_pod_selector = {
              matchLabels: {
                "app.kubernetes.io/name": "gitlab-workspaces-proxy"
              }
            }
            ingress = [{ from: [{ namespaceSelector: proxy_namespace_selector, podSelector: proxy_pod_selector }] }]

            kube_system_namespace_selector = {
              matchLabels: {
                "kubernetes.io/metadata.name": "kube-system"
              }
            }
            egress_except_cidr = [
              - "10.0.0.0/8",
              - "172.16.0.0/12",
              - "192.168.0.0/16"
            ]
            egress = [
              { to: [{ ipBlock: { cidr: "0.0.0.0/0", except: egress_except_cidr } }] },
              {
                ports: [{ port: 53, protocol: "TCP" }, { port: 53, protocol: "UDP" }],
                to: [{ namespaceSelector: kube_system_namespace_selector }]
              }
            ]

            {
              apiVersion: "networking.k8s.io/v1",
              kind: "NetworkPolicy",
              metadata: {
                annotations: annotations,
                labels: labels,
                name: name,
                namespace: namespace
              },
              spec: {
                egress: egress,
                ingress: ingress,
                podSelector: {},
                policyTypes: policy_types
              }
            }.deep_stringify_keys.to_h
          end
        end
      end
    end
  end
end
