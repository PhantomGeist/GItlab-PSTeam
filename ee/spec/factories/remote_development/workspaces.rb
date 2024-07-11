# frozen_string_literal: true

FactoryBot.define do
  factory :workspace, class: 'RemoteDevelopment::Workspace' do
    project factory: [:project, :in_group]
    user
    agent factory: [:ee_cluster_agent, :with_remote_development_agent_config]
    personal_access_token

    name { "workspace-#{agent.id}-#{user.id}-#{random_string}" }
    config_version { RemoteDevelopment::Workspaces::ConfigVersion::VERSION_2 }
    force_include_all_resources { true }

    add_attribute(:namespace) { "gl-rd-ns-#{agent.id}-#{user.id}-#{random_string}" }

    desired_state { RemoteDevelopment::Workspaces::States::STOPPED }
    actual_state { RemoteDevelopment::Workspaces::States::STOPPED }
    deployment_resource_version { 2 }
    editor { 'webide' }
    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    max_hours_before_termination { 24 }

    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    devfile_ref { 'main' }
    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    devfile_path { '.devfile.yaml' }

    devfile do
      File.read(Rails.root.join('ee/spec/fixtures/remote_development/example.devfile.yaml').to_s)
    end

    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    processed_devfile do
      File.read(Rails.root.join('ee/spec/fixtures/remote_development/example.processed-devfile.yaml').to_s)
    end

    transient do
      without_workspace_variables { false }
      random_string { SecureRandom.alphanumeric(6).downcase }
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      skip_realistic_after_create_timestamp_updates { false }
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      is_after_reconciliation_finish { false }
    end

    # Use this trait if you want to directly control any timestamp fields when invoking the factory.
    trait :without_realistic_after_create_timestamp_updates do
      transient do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        skip_realistic_after_create_timestamp_updates { true }
      end
    end

    # Use this trait if you want to simulate workspace state just after one round of reconciliation where
    # agent has already received config to apply from Rails
    trait :after_initial_reconciliation do
      transient do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        is_after_reconciliation_finish { true }
      end
    end

    after(:build) do |workspace, _|
      user = workspace.user
      workspace.project.add_developer(user)
      workspace.agent.project.add_developer(user)
      workspace.url ||= "https://60001-#{workspace.name}.#{workspace.agent.remote_development_agent_config.dns_zone}"
    end

    after(:create) do |workspace, evaluator|
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-25400
      if evaluator.skip_realistic_after_create_timestamp_updates
        # Set responded_to_agent_at to a non-nil value unless it has already been set
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        workspace.update!(responded_to_agent_at: workspace.updated_at) unless workspace.responded_to_agent_at
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-25400
      elsif evaluator.is_after_reconciliation_finish
        # The most recent activity was reconciliation where info for the workspace was reported to the agent
        # This DOES NOT necessarily mean that the actual and desired states for the workspace are now the same
        # This is because successful convergence of actual & desired states may span more than 1 reconciliation cycle
        workspace.update!(
          desired_state_updated_at: 2.seconds.ago,
          responded_to_agent_at: 1.second.ago
        )
      else
        unless evaluator.without_workspace_variables
          workspace_variables = RemoteDevelopment::Workspaces::Create::WorkspaceVariables.variables(
            name: workspace.name,
            dns_zone: workspace.dns_zone,
            personal_access_token_value: workspace.personal_access_token.token,
            user_name: workspace.user.name,
            user_email: workspace.user.email,
            workspace_id: workspace.id
          )

          workspace_variables.each do |workspace_variable|
            workspace.workspace_variables.create!(workspace_variable)
          end
        end

        if workspace.desired_state == workspace.actual_state
          # The most recent activity was a poll that reconciled the desired and actual state.
          desired_state_updated_at = 2.seconds.ago
          responded_to_agent_at = 1.second.ago
        else
          # The most recent activity was a user action which updated the desired state to be different
          # than the actual state.
          desired_state_updated_at = 1.second.ago
          responded_to_agent_at = 2.seconds.ago
        end

        workspace.update!(
          # NOTE: created_at and updated_at are not currently used in any logic, but we set them to be
          #       before desired_state_updated_at or responded_to_agent_at to ensure the record represents
          #       a realistic condition.
          created_at: 3.seconds.ago,
          updated_at: 3.seconds.ago,

          desired_state_updated_at: desired_state_updated_at,
          responded_to_agent_at: responded_to_agent_at
        )
      end
    end

    trait :unprovisioned do
      desired_state { RemoteDevelopment::Workspaces::States::RUNNING }
      actual_state { RemoteDevelopment::Workspaces::States::CREATION_REQUESTED }
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      responded_to_agent_at { nil }
      deployment_resource_version { nil }
    end

    trait :without_workspace_variables do
      transient do
        without_workspace_variables { true }
      end
    end
  end
end
