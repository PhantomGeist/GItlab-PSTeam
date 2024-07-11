# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuePolicy, :saas, feature_category: :team_planning do
  let_it_be(:owner) { create(:user) }
  let(:user) { owner }

  subject { described_class.new(user, issue) }

  context 'on group namespace' do
    let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:issue) { create(:issue, project: project) }

    before do
      namespace.add_owner(owner)

      allow(issue).to receive(:project).and_return(project)
      allow(project).to receive(:namespace).and_return(namespace)
      allow(project).to receive(:design_management_enabled?).and_return true
    end

    it { is_expected.to be_allowed(:create_issue, :update_issue, :read_issue_iid, :reopen_issue, :create_design, :create_note) }

    describe '#rules' do
      context 'on a group namespace' do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
          stub_licensed_features(summarize_notes: true, ai_features: true, generate_description: true)

          namespace.namespace_settings.update!(experiment_features_enabled: true)
          namespace.namespace_settings.update!(third_party_ai_features_enabled: true)
        end

        context 'when a member' do
          it { is_expected.to be_allowed(:summarize_notes) }
          it { is_expected.to be_allowed(:generate_description) }

          context 'when experiment features are disabled' do
            before do
              namespace.namespace_settings.update!(experiment_features_enabled: false)
            end

            it { is_expected.to be_disallowed(:summarize_notes) }
          end

          context 'when third party ai features are disabled' do
            before do
              namespace.namespace_settings.update!(third_party_ai_features_enabled: false)
            end

            it { is_expected.to be_disallowed(:summarize_notes) }
            it { is_expected.to be_disallowed(:generate_description) }
          end

          context 'when license is not set' do
            before do
              stub_licensed_features(summarize_notes: false, generate_description: false)
            end

            it { is_expected.to be_disallowed(:summarize_notes) }
            it { is_expected.to be_disallowed(:generate_description) }
          end

          context 'when feature flag is not set' do
            before do
              stub_feature_flags(openai_experimentation: false)
            end

            it { is_expected.to be_disallowed(:summarize_notes) }
            it { is_expected.to be_disallowed(:generate_description) }
          end
        end

        context 'when not a member' do
          let_it_be(:user) { create(:user) }

          it { is_expected.to be_disallowed(:summarize_notes) }
          it { is_expected.to be_disallowed(:generate_description) }
        end
      end
    end
  end

  context 'on a user namespace' do
    let_it_be(:namespace) { owner.namespace }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:issue) { create(:issue, project: project) }

    it { is_expected.to be_disallowed(:summarize_notes) }
    it { is_expected.to be_disallowed(:generate_description) }
  end
end
