# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::TodosHelper do
  include Devise::Test::ControllerHelpers

  describe '#todo_types_options' do
    it 'includes options for an epic todo' do
      expect(helper.todo_types_options).to include(
        { id: 'Epic', text: 'Epic' }
      )
    end
  end

  describe '#todo_target_path' do
    context 'when target is vulnerability' do
      let(:vulnerability) { create(:vulnerability) }
      let(:todo) { create(:todo, target: vulnerability, project: vulnerability.project) }

      subject(:todo_target_path) { helper.todo_target_path(todo) }

      it { is_expected.to eq("/#{todo.project.full_path}/-/security/vulnerabilities/#{todo.target.id}") }
    end
  end

  describe '#todo_author_display?' do
    using RSpec::Parameterized::TableSyntax

    let!(:todo) { create(:todo) }

    subject { helper.todo_author_display?(todo) }

    where(:action, :result) do
      ::Todo::MERGE_TRAIN_REMOVED | false
      ::Todo::ASSIGNED            | true
    end

    with_them do
      before do
        todo.action = action
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '#todo_target_state_pill' do
    subject { helper.todo_target_state_pill(todo) }

    shared_examples 'a rendered state pill' do |attr|
      it 'returns expected html' do
        aggregate_failures do
          expect(subject).to have_css(attr[:css])
          expect(subject).to have_content(attr[:state].capitalize)
        end
      end
    end

    shared_examples 'no state pill' do
      specify { expect(subject).to eq(nil) }
    end

    context 'in epic todo' do
      let(:todo) { create(:todo, target: create(:epic)) }

      it_behaves_like 'no state pill'

      context 'with closed epic' do
        before do
          todo.target.update!(state: 'closed')
        end

        it_behaves_like 'a rendered state pill', css: '.badge-info', state: 'closed'
      end
    end
  end

  describe '#show_todo_state?' do
    let(:closed_epic) { create(:epic, state: 'closed') }
    let(:todo) { create(:todo, target: closed_epic) }

    it 'returns true for a closed epic' do
      expect(helper.show_todo_state?(todo)).to eq(true)
    end
  end

  describe '#todo_groups_requiring_saml_reauth' do
    let_it_be(:restricted_group) do
      create(:group, saml_provider: create(:saml_provider, enabled: true, enforced_sso: true))
    end

    let_it_be(:restricted_group2) do
      create(:group, saml_provider: create(:saml_provider, enabled: true, enforced_sso: true))
    end

    let_it_be(:restricted_subgroup) { create(:group, parent: restricted_group) }
    let_it_be(:unrestricted_group) { create(:group) }

    let_it_be(:epic_todo) { create(:todo, group: restricted_group, target: create(:epic, group: restricted_subgroup)) }

    let_it_be(:restricted_project) { create(:project, namespace: restricted_group2) }

    let_it_be(:issue_todo) do
      create(:todo, project: restricted_project, target: create(:issue, project: restricted_project))
    end

    let_it_be(:issue_todo2) do
      create(:todo, project: restricted_project, target: create(:issue, project: restricted_project))
    end

    let_it_be(:unrestricted_project) { create(:project, namespace: unrestricted_group) }

    let_it_be(:mr_todo) do
      create(:todo, project: unrestricted_project, target: create(:merge_request, source_project: unrestricted_project))
    end

    let_it_be(:user_namespace) { create(:namespace) }
    let_it_be(:user_project) { create(:project, namespace: user_namespace) }
    let_it_be(:user_namespace_issue_todo) do
      create(:todo, project: user_project, target: create(:issue, project: user_project))
    end

    let_it_be(:todos) { [epic_todo, issue_todo, issue_todo2, mr_todo, user_namespace_issue_todo] }

    let(:session) { {} }

    before do
      stub_licensed_features(group_saml: true)
    end

    around do |example|
      Gitlab::Session.with_session(session) do
        example.run
      end
    end

    it 'returns root groups for todos with targets in SSO enforced groups' do
      expect(helper.todo_groups_requiring_saml_reauth(todos)).to match_array([restricted_group, restricted_group2])
    end

    it 'sends a unique list of groups to the SSO enforcer' do
      expect(::Gitlab::Auth::GroupSaml::SsoEnforcer)
        .to receive(:access_restricted_groups).with([restricted_group, restricted_group2, unrestricted_group], any_args)

      helper.todo_groups_requiring_saml_reauth(todos)
    end
  end

  describe '#todo_target_path_anchor' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:author) { create(:user) }

    describe 'with a mentioned todo' do
      let_it_be(:todo) do
        create(:todo,
          :mentioned,
          user: user,
          project: project,
          target: merge_request,
          author: author)
      end

      it { expect(helper.todo_target_path_anchor(todo)).to eq(nil) }
    end

    describe 'with a review requested todo' do
      let_it_be(:todo) do
        create(:todo,
          :review_requested,
          user: user,
          project: project,
          target: merge_request,
          author: author)
      end

      context 'when the summarize LLM feature is disabled' do
        before do
          allow(::Llm::MergeRequests::SummarizeDiffService).to receive(:enabled?).and_return(false)
        end

        it { expect(helper.todo_target_path_anchor(todo)).to eq(nil) }
      end

      context 'when the summarize LLM feature is enabled' do
        let(:summary) { instance_double('MergeRequestDiff', merge_request_diff_llm_summary: 'summary') }

        before do
          allow(merge_request).to receive(:latest_merge_request_diff).and_return(summary)
          allow(::Llm::MergeRequests::SummarizeDiffService).to receive(:enabled?).and_return(true)
        end

        context 'without llm summary' do
          let(:summary) { instance_double('MergeRequestDiff', merge_request_diff_llm_summary: nil) }

          it { expect(helper.todo_target_path_anchor(todo)).to eq(nil) }
        end

        context 'with llm summary' do
          it { expect(helper.todo_target_path_anchor(todo)).to eq('diff-summary') }
        end
      end
    end
  end
end
