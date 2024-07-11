# frozen_string_literal: true

require 'devfile'

module RemoteDevelopment
  module Workspaces
    module Reconcile
      module Output
        # noinspection RubyClassMethodNamingConvention - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
        class DevfileParser
          # rubocop:disable Metrics/ParameterLists
          # @param [String] processed_devfile
          # @param [String] name
          # @param [String] namespace
          # @param [Integer] replicas
          # @param [String] domain_template
          # @param [Hash] labels
          # @param [Hash] annotations
          # @param [Array<String>] env_secret_names
          # @param [Array<String>] file_secret_names
          # @param [RemoteDevelopment::Logger] logger
          # @return [Array<Hash>]
          def self.get_all(
            processed_devfile:,
            name:,
            namespace:,
            replicas:,
            domain_template:,
            labels:,
            annotations:,
            env_secret_names:,
            file_secret_names:,
            logger:
          )
            begin
              workspace_resources_yaml = Devfile::Parser.get_all(
                processed_devfile,
                name,
                namespace,
                YAML.dump(labels.deep_stringify_keys),
                YAML.dump(annotations.deep_stringify_keys),
                replicas,
                domain_template,
                'none'
              )
            rescue Devfile::CliError => e
              logger.warn(
                message: 'Error parsing devfile with Devfile::Parser.get_all',
                error_type: 'reconcile_devfile_parser_error',
                workspace_name: name,
                workspace_namespace: namespace,
                devfile_parser_error: e.message
              )
              return []
            end

            workspace_resources = YAML.load_stream(workspace_resources_yaml)
            workspace_resources = set_security_context(workspace_resources: workspace_resources)
            inject_secrets(
              workspace_resources: workspace_resources,
              env_secret_names: env_secret_names,
              file_secret_names: file_secret_names
            )
          end
          # rubocop:enable Metrics/ParameterLists

          # Devfile library allows specifying the security context of pods/containers as mentioned in
          # https://github.com/devfile/api/issues/920 through `pod-overrides` and `container-overrides` attributes.
          # However, https://github.com/devfile/library/pull/158 which is implementing this feature,
          # is not part of v2.2.0 which is the latest release of the devfile which is being used in the devfile-gem.
          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409189
          #       Once devfile library releases a new version, update the devfile-gem and move
          #       the logic of setting the security context as part of workspace creation.
          RUN_AS_USER = 5001

          # @param [Array<Hash>] workspace_resources
          # @return [Array<Hash>]
          def self.set_security_context(workspace_resources:)
            workspace_resources.each do |workspace_resource|
              next unless workspace_resource['kind'] == 'Deployment'

              pod_security_context = {
                'runAsNonRoot' => true,
                'runAsUser' => RUN_AS_USER,
                'fsGroup' => 0,
                'fsGroupChangePolicy' => 'OnRootMismatch'
              }
              container_security_context = {
                'allowPrivilegeEscalation' => false,
                'privileged' => false,
                'runAsNonRoot' => true,
                'runAsUser' => RUN_AS_USER
              }

              pod_spec = workspace_resource['spec']['template']['spec']
              # Explicitly set security context for the pod
              pod_spec['securityContext'] = pod_security_context
              # Explicitly set security context for all containers
              pod_spec['containers'].each do |container|
                container['securityContext'] = container_security_context
              end
              # Explicitly set security context for all init containers
              pod_spec['initContainers'].each do |init_container|
                init_container['securityContext'] = container_security_context
              end
            end
            workspace_resources
          end

          # @param [Array<Hash>] workspace_resources
          # @param [Array<String>] env_secret_names
          # @param [Array<String>] file_secret_names
          # @return [Array<Hash>]
          def self.inject_secrets(workspace_resources:, env_secret_names:, file_secret_names:)
            workspace_resources.each do |workspace_resource|
              next unless workspace_resource.fetch('kind') == 'Deployment'

              volume_name = 'gl-workspace-variables'
              volumes = [
                {
                  'name' => volume_name,
                  'projected' => {
                    'defaultMode' => 0o774,
                    'sources' => file_secret_names.map { |v| { 'secret' => { 'name' => v } } }
                  }
                }
              ]
              volume_mounts = [
                {
                  'name' => volume_name,
                  'mountPath' => RemoteDevelopment::Workspaces::FileMounts::VARIABLES_FILE_DIR
                }
              ]
              env_from = env_secret_names.map { |v| { 'secretRef' => { 'name' => v } } }

              pod_spec = workspace_resource.fetch('spec').fetch('template').fetch('spec')
              pod_spec.fetch('volumes').concat(volumes) unless file_secret_names.empty?

              pod_spec.fetch('initContainers').each do |init_container|
                init_container.fetch('volumeMounts').concat(volume_mounts) unless file_secret_names.empty?
                init_container['envFrom'] = env_from unless env_secret_names.empty?
              end

              pod_spec.fetch('containers').each do |container|
                container.fetch('volumeMounts').concat(volume_mounts) unless file_secret_names.empty?
                container['envFrom'] = env_from unless env_secret_names.empty?
              end
            end
            workspace_resources
          end
        end
      end
    end
  end
end
