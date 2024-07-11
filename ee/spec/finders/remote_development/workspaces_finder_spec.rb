# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspacesFinder, feature_category: :remote_development do
  include ::RemoteDevelopment::Workspaces::States

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project_a) { create(:project, :public) }
  let_it_be(:project_b) { create(:project, :public) }
  let_it_be(:workspace_a) do
    create(:workspace, user: current_user, updated_at: 2.days.ago, project_id: project_a.id,
      actual_state: ::RemoteDevelopment::Workspaces::States::RUNNING
    )
  end

  let_it_be(:workspace_b) do
    create(:workspace, user: current_user, updated_at: 1.day.ago, project_id: project_b.id,
      actual_state: ::RemoteDevelopment::Workspaces::States::TERMINATED
    )
  end

  subject { described_class.new(current_user, params).execute }

  context 'with valid license' do
    before do
      stub_licensed_features(remote_development: true)
    end

    context 'with blank params' do
      let(:params) { {} }

      it "returns current user's workspaces sorted by last updated time (most recent first)" do
        workspaces = subject.to_ary

        # The assertions below can be replaced concisely with
        #   eq([workspace_b, workspace_a])
        # However, doing so results in a dangerbot warning that is difficult to suppress
        # Unfortunatly there isn't an exact-order array matcher that doesn't result in a dangerbot warning.
        expect(workspaces.length).to eq(2)
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
        expect(workspaces.first).to eq(workspace_b)
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
        expect(workspaces.last).to eq(workspace_a)
      end
    end

    context 'with id in params' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
      let(:params) { { ids: [workspace_a.id] } }

      it "returns only current user's workspaces matching the specified IDs" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
        expect(subject).to contain_exactly(workspace_a)
      end
    end

    context 'with project_ids in params' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
      let(:params) { { project_ids: [project_a.id] } }

      it "returns only current user's workspaces matching the specified project IDs" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
        expect(subject).to contain_exactly(workspace_a)
      end
    end

    context 'with include_actual_states in params' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
      let(:params) { { include_actual_states: [::RemoteDevelopment::Workspaces::States::RUNNING] } }

      it "returns only current user's workspaces not matching the specified actual_states" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
        expect(subject).to contain_exactly(workspace_a)
      end
    end

    context 'without current user' do
      subject { described_class.new(nil, params).execute }

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
      let(:params) { { ids: [workspace_a.id] } }

      it 'returns none' do
        expect(subject).to be_blank
      end
    end
  end

  context 'without valid license' do
    let(:params) { {} }

    it 'returns none' do
      expect(subject).to be_blank
    end
  end
end
