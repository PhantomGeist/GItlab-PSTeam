# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ResourceAccess, feature_category: :duo_chat do
  describe '.ai_enabled_for_resource?' do
    let_it_be(:user) { build_stubbed(:user) }
    let(:third_party_ai_features_enabled) { false }
    let(:experiment_features_enabled) { false }
    let(:namespace_settings) do
      build_stubbed(:namespace_settings,
        third_party_ai_features_enabled: third_party_ai_features_enabled,
        experiment_features_enabled: experiment_features_enabled)
    end

    let(:namespace) { build_stubbed(:namespace, namespace_settings: namespace_settings) }
    let(:root_group) { build_stubbed(:group, namespace_settings: namespace_settings) }
    let(:some_group) { build_stubbed(:group, parent: root_group) }
    let(:project) { build_stubbed(:project, namespace: namespace) }

    let(:resource) { nil }

    subject { described_class.ai_enabled_for_resource?(resource) }

    context 'when resource is user' do
      let(:resource) { user }

      context 'when user has access to ai' do
        it 'is expected to return true' do
          expect(resource).to receive(:any_group_with_ai_available?).and_return(true)

          is_expected.to eq(true)
        end
      end

      context 'when user does not have access to ai' do
        it { is_expected.to eq(false) }
      end
    end

    context 'when resource is group' do
      let(:resource) { some_group }

      context 'when group has access to ai' do
        let(:third_party_ai_features_enabled) { true }
        let(:experiment_features_enabled) { true }

        it { is_expected.to eq(true) }
      end

      context 'when group does not have access to ai' do
        it { is_expected.to eq(false) }
      end
    end

    context 'when resource is project' do
      let(:resource) { project }

      context 'when project has access to ai' do
        let(:third_party_ai_features_enabled) { true }
        let(:experiment_features_enabled) { true }

        it { is_expected.to eq(true) }
      end

      context 'when project does not have access to ai' do
        it { is_expected.to eq(false) }
      end
    end

    context 'when resource is neither user group or project' do
      it { is_expected.to eq(false) }
    end
  end
end
