# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::GenerateSummaryService, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let(:summarize_notes_enabled) { true }
  let(:current_user) { user }

  describe '#perform' do
    before do
      group.add_guest(user)

      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :summarize_notes, resource).and_return(summarize_notes_enabled)
    end

    subject { described_class.new(current_user, resource, {}).execute }

    shared_examples 'ensures user membership' do
      context 'without membership' do
        let(:current_user) { create(:user) }

        it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
      end
    end

    shared_examples 'ensures feature flags and license' do
      context 'without the license available' do
        let(:summarize_notes_enabled) { false }

        it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
      end

      context 'without the general feature flag enabled' do
        before do
          stub_feature_flags(openai_experimentation: false)
        end

        it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
      end
    end

    context 'for an issue' do
      let_it_be(:resource) { create(:issue, project: project) }

      context 'with notes' do
        let(:action_name) { :summarize_comments }
        let(:options) { { ai_provider: :vertex_ai } }
        let(:content) { 'Summarize comments' }

        before do
          create_pair(:note_on_issue, project: resource.project, noteable: resource)
        end

        it_behaves_like "ensures feature flags and license"
        it_behaves_like "ensures user membership"
        it_behaves_like 'schedules completion worker' do
          subject { described_class.new(current_user, resource, options) }
        end
      end
    end

    context 'for a work item' do
      let_it_be(:resource) { create(:work_item, project: project) }

      context 'with notes' do
        let(:action_name) { :summarize_comments }
        let(:options) { { ai_provider: :vertex_ai } }
        let(:content) { 'Summarize comments' }

        before do
          create_pair(:note_on_work_item, project: resource.project, noteable: resource)
        end

        it_behaves_like "ensures feature flags and license"
        it_behaves_like "ensures user membership"
        it_behaves_like 'schedules completion worker' do
          subject { described_class.new(current_user, resource, options) }
        end
      end
    end

    context 'for an epic' do
      let(:action_name) { :summarize_comments }
      let(:options) { { ai_provider: :vertex_ai } }
      let(:content) { 'Summarize comments' }
      let_it_be(:resource) { create(:epic, group: group) }

      context 'with notes' do
        before do
          create_pair(:note_on_epic, noteable: resource)
        end

        it_behaves_like "ensures feature flags and license"
        it_behaves_like "ensures user membership"
        it_behaves_like 'schedules completion worker' do
          subject { described_class.new(current_user, resource, options) }
        end
      end
    end
  end
end
