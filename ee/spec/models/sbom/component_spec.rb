# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Component, type: :model, feature_category: :dependency_management do
  let(:component_types) { { library: 0 } }

  let(:purl_types) do
    {
      composer: 1,
      conan: 2,
      gem: 3,
      golang: 4,
      maven: 5,
      npm: 6,
      nuget: 7,
      pypi: 8,
      apk: 9,
      rpm: 10,
      deb: 11,
      cbl_mariner: 12
    }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:component_type).with_values(component_types) }
    it { is_expected.to define_enum_for(:purl_type).with_values(purl_types) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:component_type) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
  end

  describe '.libraries scope' do
    let_it_be(:library_sbom_component) { create(:sbom_component, component_type: :library) }

    subject { described_class.libraries }

    it { is_expected.to include(library_sbom_component) }
  end

  describe '.by_purl_type_and_name scope' do
    let_it_be(:matching_sbom_component) { create(:sbom_component, purl_type: 'npm', name: 'component-1') }
    let_it_be(:non_matching_sbom_component) { create(:sbom_component, purl_type: 'golang', name: 'component-2') }

    subject { described_class.by_purl_type_and_name('npm', 'component-1') }

    it { is_expected.to include(matching_sbom_component) }
    it { is_expected.not_to include(non_matching_sbom_component) }
  end
end
