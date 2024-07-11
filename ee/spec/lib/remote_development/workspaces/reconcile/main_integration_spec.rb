# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::Workspaces::Reconcile::Main, "Integration", :freeze_time, feature_category: :remote_development do
  include_context 'with remote development shared fixtures'

  shared_examples 'max_hours_before_termination handling' do
    it 'sets desired_state to Terminated' do
      response = subject
      expect(response[:message]).to be_nil
      expect(response.dig(:payload, :workspace_rails_infos)).not_to be_nil

      expect(workspace.reload.desired_state).to eq(RemoteDevelopment::Workspaces::States::TERMINATED)
    end
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:agent) { create(:ee_cluster_agent, :with_remote_development_agent_config) }

  let(:logger) { instance_double(::Logger) }

  let(:expected_value_for_started) { true }

  subject do
    described_class.main(
      agent: agent,
      logger: logger,
      original_params: {
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      }
    )
  end

  before do
    allow(logger).to receive(:debug)
  end

  context 'when update_type is full' do
    let(:update_type) { RemoteDevelopment::Workspaces::Reconcile::UpdateTypes::FULL }
    let(:workspace_agent_infos) { [] }

    it 'updates workspace record and returns proper workspace_rails_info entry' do
      create(:workspace, agent: agent, user: user, force_include_all_resources: false)
      response = subject
      expect(response[:message]).to be_nil
      workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
      expect(workspace_rails_infos.length).to eq(1)
      workspace_rails_info = workspace_rails_infos.first

      # NOTE: We don't care about any specific expectations, just that the existing workspace
      #       still has a config returned in the rails_info response even though it was not sent by the agent.
      expect(workspace_rails_info[:config_to_apply]).not_to be_nil
    end
  end

  context 'when update_type is partial' do
    let(:update_type) { RemoteDevelopment::Workspaces::Reconcile::UpdateTypes::PARTIAL }

    context 'when receiving agent updates for a workspace which exists in the db' do
      let(:desired_state) { RemoteDevelopment::Workspaces::States::STOPPED }
      let(:actual_state) { current_actual_state }
      let(:previous_actual_state) { RemoteDevelopment::Workspaces::States::STOPPING }
      let(:current_actual_state) { RemoteDevelopment::Workspaces::States::STOPPED }
      let(:workspace_exists) { false }
      let(:deployment_resource_version_from_agent) { '2' }
      let(:expected_desired_state) { desired_state }
      let(:expected_actual_state) { actual_state }
      let(:expected_deployment_resource_version) { deployment_resource_version_from_agent }
      let(:expected_config_to_apply) { nil }
      let(:error_from_agent) { nil }

      let(:workspace_agent_info) do
        create_workspace_agent_info_hash(
          workspace: workspace,
          previous_actual_state: previous_actual_state,
          current_actual_state: current_actual_state,
          workspace_exists: workspace_exists,
          resource_version: deployment_resource_version_from_agent,
          error_details: error_from_agent
        )
      end

      let(:workspace_agent_infos) { [workspace_agent_info] }

      let(:expected_workspace_rails_info) do
        {
          name: workspace.name,
          namespace: workspace.namespace,
          desired_state: expected_desired_state,
          actual_state: expected_actual_state,
          deployment_resource_version: expected_deployment_resource_version,
          config_to_apply: expected_config_to_apply
        }
      end

      let(:expected_workspace_rails_infos) { [expected_workspace_rails_info] }

      let(:workspace) do
        create(
          :workspace,
          agent: agent,
          user: user,
          desired_state: desired_state,
          actual_state: actual_state,
          force_include_all_resources: false
        )
      end

      context 'with max_hours_before_termination expired' do
        let(:workspace) do
          create(
            :workspace,
            :without_realistic_after_create_timestamp_updates,
            agent: agent,
            user: user,
            desired_state: desired_state,
            actual_state: actual_state,
            max_hours_before_termination: 24,
            created_at: 25.hours.ago,
            force_include_all_resources: false
          )
        end

        context 'when state would otherwise be sent' do
          let(:desired_state) { RemoteDevelopment::Workspaces::States::STOPPED }
          let(:actual_state) { RemoteDevelopment::Workspaces::States::RUNNING }

          it_behaves_like 'max_hours_before_termination handling'
        end

        context 'when desired_state is RestartRequested and actual_state is Stopped' do
          let(:desired_state) { RemoteDevelopment::Workspaces::States::RESTART_REQUESTED }
          let(:actual_state) { RemoteDevelopment::Workspaces::States::STOPPED }

          it_behaves_like 'max_hours_before_termination handling'
        end
      end

      context "when the agent encounters an error while starting the workspace" do
        let(:actual_state) { RemoteDevelopment::Workspaces::States::STARTING }
        let(:desired_state) { RemoteDevelopment::Workspaces::States::RUNNING }
        let(:expected_actual_state) { RemoteDevelopment::Workspaces::States::ERROR }
        let(:error_from_agent) do
          {
            error_type: RemoteDevelopment::Workspaces::Reconcile::ErrorType::APPLIER,
            error_message: "some applier error"
          }
        end

        let(:workspace) do
          create(
            :workspace,
            :after_initial_reconciliation,
            agent: agent,
            user: user,
            desired_state: desired_state,
            actual_state: actual_state,
            force_include_all_resources: false
          )
        end

        it 'returns proper workspace_rails_info entry with no config to apply' do
          # verify initial states in db (sanity check of match between factory and fixtures)
          expect(workspace.desired_state).to eq(desired_state)
          expect(workspace.actual_state).to eq(actual_state)

          # expect abnormal agent info to be logged at warn level
          expect(logger).to receive(:warn).with(hash_including(error_type: "abnormal_actual_state"))

          response = subject
          expect(response[:message]).to be_nil
          workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
          expect(workspace_rails_infos.length).to eq(1)

          workspace.reload

          expect(workspace.deployment_resource_version)
            .to eq(expected_deployment_resource_version)

          # test the config to apply first to get a more specific diff if it fails
          # noinspection RubyLocalVariableNamingConvention - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
          provisioned_workspace_rails_info =
            workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
          # Since the workspace is now in Error state, the config should not be returned to the agent
          expect(provisioned_workspace_rails_info.fetch(:config_to_apply)).to be_nil

          # then test everything in the infos
          expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
        end
      end

      # rubocop:disable RSpec/MultipleMemoizedHelpers
      context 'when only some workspaces fail in devfile flattener' do
        let(:workspace) do
          create(:workspace, name: "workspace1", agent: agent, user: user, force_include_all_resources: false)
        end

        let(:workspace2) do
          create(:workspace, devfile: invalid_devfile_yaml, name: "workspace-failing-flatten",
            agent: agent, user: user, force_include_all_resources: false)
        end

        let(:invalid_devfile_yaml) { read_devfile('example.invalid-extra-field-devfile.yaml') }

        let(:workspace2_agent_info) do
          create_workspace_agent_info_hash(
            workspace: workspace2,
            previous_actual_state: previous_actual_state,
            current_actual_state: current_actual_state,
            workspace_exists: workspace_exists,
            resource_version: deployment_resource_version_from_agent
          )
        end

        # NOTE: Reverse the order so that the failing one is processed first and ensures that the second valid
        #       one is still processed successfully.
        let(:workspace_agent_infos) { [workspace2_agent_info, workspace_agent_info] }

        let(:expected_workspace2_rails_info) do
          {
            name: workspace2.name,
            namespace: workspace2.namespace,
            desired_state: expected_desired_state,
            actual_state: expected_actual_state,
            deployment_resource_version: expected_deployment_resource_version,
            config_to_apply: nil
          }
        end

        let(:expected_workspace_rails_infos) { [expected_workspace2_rails_info, expected_workspace_rails_info] }

        it 'returns proper workspace_rails_info entries' do
          response = subject
          expect(response[:message]).to be_nil
          workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
          expect(workspace_rails_infos.length).to eq(2)

          workspace.reload
          workspace2.reload

          expect(workspace.deployment_resource_version)
            .to eq(expected_deployment_resource_version)

          expect(workspace2.deployment_resource_version)
            .to eq(expected_deployment_resource_version)

          workspace2_rails_info =
            workspace_rails_infos.detect { |info| info.fetch(:name) == workspace2.name }
          expect(workspace2_rails_info.fetch(:config_to_apply)).to be_nil

          # then test everything in the infos
          expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
        end
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      context 'with timestamp precondition checks' do
        # NOTE: rubocop:disable RSpec/ExpectInHook could be avoided with a helper method or custom expectation,
        #       but this works for now.
        # rubocop:disable RSpec/ExpectInHook
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        before do
          # Ensure that both desired_state_updated_at and responded_to_agent_at are before Time.current,
          # so that we can test for any necessary differences after processing updates them
          expect(workspace.desired_state_updated_at).to be_before(Time.current)
          expect(workspace.responded_to_agent_at).to be_before(Time.current)
        end

        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        after do
          # After processing, the responded_to_agent_at should always have been updated
          workspace.reload
          expect(workspace.responded_to_agent_at)
            .not_to be_before(workspace.desired_state_updated_at)
        end
        # rubocop:enable RSpec/ExpectInHook

        context 'when desired_state matches actual_state' do
          # rubocop:disable RSpec/ExpectInHook
          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          before do
            expect(workspace.responded_to_agent_at)
              .to be_after(workspace.desired_state_updated_at)
          end
          # rubocop:enable RSpec/ExpectInHook

          context 'when state is Stopped' do
            let(:desired_state) { RemoteDevelopment::Workspaces::States::STOPPED }

            it 'updates workspace record and returns proper workspace_rails_info entry' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              response = subject
              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload

              expect(workspace.desired_state).to eq(workspace.actual_state)
              expect(workspace.deployment_resource_version)
                .to eq(expected_deployment_resource_version)

              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end

          context 'when state is Terminated' do
            let(:desired_state) { RemoteDevelopment::Workspaces::States::TERMINATED }
            let(:previous_actual_state) { RemoteDevelopment::Workspaces::States::TERMINATED }
            let(:current_actual_state) { RemoteDevelopment::Workspaces::States::TERMINATED }
            let(:expected_deployment_resource_version) { workspace.deployment_resource_version }

            it 'updates workspace record and returns proper workspace_rails_info entry' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              # We could do this with a should_not_change block but this reads cleaner IMO
              response = subject
              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload

              expect(workspace.desired_state).to eq(workspace.actual_state)
              expect(workspace.deployment_resource_version)
                .to eq(expected_deployment_resource_version)

              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end
        end

        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        context 'when desired_state does not match actual_state' do
          let(:deployment_resource_version_from_agent) { workspace.deployment_resource_version }

          let(:expected_config_to_apply) do
            create_config_to_apply(workspace: workspace, started: expected_value_for_started)
          end

          let(:expected_workspace_rails_infos) { [expected_workspace_rails_info] }

          # rubocop:disable RSpec/ExpectInHook
          before do
            # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
            expect(workspace.responded_to_agent_at)
              .to be_before(workspace.desired_state_updated_at)
          end
          # rubocop:enable RSpec/ExpectInHook

          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          context 'when desired_state is Running' do
            let(:desired_state) { RemoteDevelopment::Workspaces::States::RUNNING }

            # noinspection RubyLocalVariableNamingConvention - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
            it 'returns proper workspace_rails_info entry with config_to_apply' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              response = subject
              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload

              expect(workspace.deployment_resource_version)
                .to eq(expected_deployment_resource_version)

              # test the config to apply first to get a more specific diff if it fails
              provisioned_workspace_rails_info =
                workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
              expect(provisioned_workspace_rails_info.fetch(:config_to_apply))
                .to eq(expected_workspace_rails_info.fetch(:config_to_apply))

              # then test everything in the infos
              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end

          context 'when desired_state is Terminated' do
            let(:desired_state) { RemoteDevelopment::Workspaces::States::TERMINATED }
            let(:expected_value_for_started) { false }

            # noinspection RubyLocalVariableNamingConvention - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
            it 'returns proper workspace_rails_info entry with config_to_apply' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              response = subject
              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload

              expect(workspace.deployment_resource_version)
                .to eq(expected_deployment_resource_version)

              # test the config to apply first to get a more specific diff if it fails
              provisioned_workspace_rails_info =
                workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
              expect(provisioned_workspace_rails_info.fetch(:config_to_apply))
                .to eq(expected_workspace_rails_info.fetch(:config_to_apply))

              # then test everything in the infos
              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end

          context 'when desired_state is RestartRequested and actual_state is Stopped' do
            let(:desired_state) { RemoteDevelopment::Workspaces::States::RESTART_REQUESTED }
            let(:expected_desired_state) { RemoteDevelopment::Workspaces::States::RUNNING }

            # noinspection RubyLocalVariableNamingConvention - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
            it 'changes desired_state to Running' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              response = subject
              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload
              expect(workspace.desired_state).to eq(expected_desired_state)

              # test the config to apply first to get a more specific diff if it fails
              provisioned_workspace_rails_info =
                workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
              expect(provisioned_workspace_rails_info[:config_to_apply])
                .to eq(expected_workspace_rails_info.fetch(:config_to_apply))

              # then test everything in the infos
              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end

          context 'when actual_state is Unknown' do
            let(:current_actual_state) { RemoteDevelopment::Workspaces::States::UNKNOWN }
            let(:expected_actual_state) { RemoteDevelopment::Workspaces::States::UNKNOWN }
            let(:expected_value_for_started) { false }

            let(:expected_config_to_apply) do
              create_config_to_apply(workspace: workspace, started: expected_value_for_started)
            end

            it 'returns the proper response' do
              # expect abnormal agent info to be logged at warn level
              expect(logger).to receive(:warn).with(hash_including(error_type: "abnormal_actual_state"))

              response = subject
              expect(response[:message]).to be_nil

              # Do redundant but progressively higher level checks on the response, so we can have better diffs
              # for debugging if any of the lower-level checks fail.
              config_to_apply_hash = YAML.safe_load(
                response[:payload].fetch(:workspace_rails_infos)[0][:config_to_apply]
              )
              expected_config_to_apply_hash = YAML.safe_load(expected_config_to_apply)
              expect(config_to_apply_hash).to eq(expected_config_to_apply_hash)

              expect(response[:payload][:workspace_rails_infos][0][:config_to_apply]).to eq(expected_config_to_apply)

              expect(response[:payload][:workspace_rails_infos]).to eq(expected_workspace_rails_infos)
            end
          end
        end
      end
    end

    context 'when receiving agent updates for a workspace which does not exist in the db' do
      let(:nonexistent_workspace) do
        instance_double(RemoteDevelopment::Workspace, id: 1, name: 'x', namespace: 'x', agent: agent)
      end

      let(:workspace_agent_info) do
        create_workspace_agent_info_hash(
          workspace: nonexistent_workspace,
          previous_actual_state: RemoteDevelopment::Workspaces::States::STOPPING,
          current_actual_state: RemoteDevelopment::Workspaces::States::STOPPED,
          workspace_exists: false,
          workspace_variables_env_var: {},
          workspace_variables_file: {}
        )
      end

      let(:workspace_agent_infos) { [workspace_agent_info] }

      let(:expected_workspace_rails_infos) { [] }

      it 'logs orphaned workspace and does not attempt to update the workspace in the db' do
        expect(logger).to receive(:warn).with(hash_including(error_type: "orphaned_workspace"))
        response = subject
        expect(response[:message]).to be_nil
        workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
        expect(workspace_rails_infos).to be_empty
      end
    end

    context 'when new unprovisioned workspace exists in database"' do
      let(:desired_state) { RemoteDevelopment::Workspaces::States::RUNNING }
      let(:actual_state) { RemoteDevelopment::Workspaces::States::CREATION_REQUESTED }

      let_it_be(:unprovisioned_workspace) do
        create(:workspace, :unprovisioned, agent: agent, user: user)
      end

      let(:workspace_agent_infos) { [] }

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      let(:expected_config_to_apply) do
        create_config_to_apply(
          workspace: unprovisioned_workspace,
          started: expected_value_for_started,
          include_all_resources: true
        )
      end

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      let(:expected_unprovisioned_workspace_rails_info) do
        {
          name: unprovisioned_workspace.name,
          namespace: unprovisioned_workspace.namespace,
          desired_state: desired_state,
          actual_state: actual_state,
          deployment_resource_version: nil,
          config_to_apply: expected_config_to_apply
        }
      end

      let(:expected_workspace_rails_infos) { [expected_unprovisioned_workspace_rails_info] }

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      # noinspection RubyLocalVariableNamingConvention - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
      it 'returns proper workspace_rails_info entry' do
        # verify initial states in db (sanity check of match between factory and fixtures)
        expect(unprovisioned_workspace.desired_state).to eq(desired_state)
        expect(unprovisioned_workspace.actual_state).to eq(actual_state)

        response = subject
        expect(response[:message]).to be_nil
        workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
        expect(workspace_rails_infos.length).to eq(1)

        # test the config to apply first to get a more specific diff if it fails
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        unprovisioned_workspace_rails_info =
          workspace_rails_infos.detect { |info| info.fetch(:name) == unprovisioned_workspace.name }
        expect(unprovisioned_workspace_rails_info.fetch(:config_to_apply))
          .to eq(expected_unprovisioned_workspace_rails_info.fetch(:config_to_apply))

        # then test everything in the infos
        expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
      end
    end
  end
end
