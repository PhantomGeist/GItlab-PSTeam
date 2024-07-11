# frozen_string_literal: true

require 'fast_spec_helper'
require 'rspec-parameterized'

RSpec.describe Gitlab::Saas, feature_category: :shared do
  describe '.feature_available?' do
    using RSpec::Parameterized::TableSyntax

    let(:feature) { described_class::FEATURES.first }

    subject(:feature_available?) { described_class.feature_available?(feature) } # rubocop:disable Gitlab/FeatureAvailableUsage

    context 'with an existing feature' do
      before do
        allow(Gitlab).to receive(:com?).and_return(com?)
      end

      context 'when on .com' do
        let(:com?) { true }

        it { is_expected.to eq true }
      end

      context 'when not on .com' do
        let(:com?) { false }

        it { is_expected.to eq false }
      end
    end

    context 'with an invalid feature' do
      let(:feature) { '_bogus_feature_' }

      it 'raises an error' do
        expect { feature_available? }.to raise_error(EE::Gitlab::Saas::MissingFeatureError, 'Feature does not exist')
      end
    end
  end

  context 'with saas feature file check' do
    where(
      case_names: ->(feature) { described_class.feature_file_path(feature) },
      feature: described_class::FEATURES
    )

    with_them do
      it 'exists for the defined_feature' do
        expect(File.exist?(Gitlab::Saas.feature_file_path(feature))).to be_truthy
      end
    end
  end
end
