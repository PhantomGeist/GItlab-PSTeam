# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::GenerateDescriptionService, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let(:options) { {} }
  let(:current_user) { user }
  let(:service) { described_class.new(current_user, resource, options) }
  let(:generate_description_license_enabled) { true }

  describe '#perform' do
    before do
      stub_licensed_features(generate_description: true)
      group.namespace_settings.update!(third_party_ai_features_enabled: true)
      group.add_guest(user)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
        .with(user, :generate_description, resource).and_return(generate_description_license_enabled)
    end

    subject { service.execute }

    shared_examples 'ensures user membership' do
      context 'without membership' do
        let(:current_user) { create(:user) }

        it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
      end
    end

    shared_examples 'ensures license and feature flag checks' do
      using RSpec::Parameterized::TableSyntax

      where(:generate_description_license_enabled, :openai_experimentation_ff, :result) do
        true  | true  | true
        true  | false | false
        false | true  | false
        false | false | false
      end

      with_them do
        it 'checks validity' do
          stub_feature_flags(openai_experimentation: openai_experimentation_ff)

          expect(service.valid?).to be(result)
          is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) unless result
        end
      end
    end

    context 'for an issue' do
      let(:action_name) { :generate_description }
      let(:content) { 'Generate description' }
      let_it_be(:resource) { create(:issue, project: project) }

      it_behaves_like "ensures license and feature flag checks"
      it_behaves_like "ensures user membership"

      it_behaves_like 'schedules completion worker' do
        subject { service }
      end
    end
  end
end
