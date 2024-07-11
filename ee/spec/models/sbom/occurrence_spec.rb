# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Occurrence, type: :model, feature_category: :dependency_management do
  let_it_be(:occurrence) { build(:sbom_occurrence) }

  describe 'associations' do
    it { is_expected.to belong_to(:component).required }
    it { is_expected.to belong_to(:component_version) }
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to belong_to(:source) }
  end

  describe 'loose foreign key on sbom_occurrences.pipeline_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:ci_pipeline) }
      let!(:model) { create(:sbom_occurrence, pipeline: parent) }
    end
  end

  describe 'validations' do
    subject { build(:sbom_occurrence) }

    it { is_expected.to validate_presence_of(:commit_sha) }
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_uniqueness_of(:uuid).case_insensitive }
    it { is_expected.to validate_length_of(:package_manager).is_at_most(255) }
    it { is_expected.to validate_length_of(:component_name).is_at_most(255) }
    it { is_expected.to validate_length_of(:input_file_path).is_at_most(255) }

    describe '#licenses' do
      subject { build(:sbom_occurrence, licenses: licenses) }

      let(:apache) do
        {
          spdx_identifier: 'Apache-2.0',
          name: 'Apache License 2.0',
          url: 'http://spdx.org/licenses/Apache-2.0.html'
        }
      end

      let(:mit) do
        {
          spdx_identifier: 'MIT',
          name: 'MIT License',
          url: 'http://spdx.org/licenses/MIT.html'
        }
      end

      context 'when licenses is empty' do
        let(:licenses) { [] }

        it { is_expected.to be_valid }
      end

      context 'when licenses has a single valid license' do
        let(:licenses) { [mit] }

        it { is_expected.to be_valid }
      end

      context 'when licenses has multiple valid licenses' do
        let(:licenses) { [apache, mit] }

        it { is_expected.to be_valid }
      end

      context 'when spdx_identifier is missing' do
        let(:licenses) { [mit.except(:spdx_identifier)] }

        it { is_expected.to be_invalid }
      end

      context 'when spdx_identifier is blank' do
        let(:licenses) { [mit.merge(spdx_identifier: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when spdx_identifier is too long' do
        # max length derived from `pm_licenses`.`spdx_identifier` column
        let(:licenses) { [mit.merge(spdx_identifier: 'X' * 51)] }

        it { is_expected.to be_invalid }
      end

      context 'when a license name is missing' do
        let(:licenses) { [mit.except(:name)] }

        it { is_expected.to be_invalid }
      end

      context 'when a license name is blank' do
        let(:licenses) { [mit.merge(name: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when a license url is missing' do
        let(:licenses) { [mit.except(:url)] }

        it { is_expected.to be_invalid }
      end

      context 'when a license url is blank' do
        let(:licenses) { [mit.merge(url: '')] }

        it { is_expected.to be_invalid }
      end

      context 'when a license contains unknown properties' do
        let(:licenses) { [mit.merge(unknown: 'value')] }

        it { is_expected.to be_invalid }
      end
    end

    describe '#vulnerabilities' do
      subject { build(:sbom_occurrence, vulnerabilities: vulnerabilities) }

      let(:info) do
        { id: 1, name: "name 1", severity: "info", url: "http://url.com/name1" }
      end

      let(:critical) do
        { id: 2, name: "name 2", severity: "critical", url: "http://url.com/name2" }
      end

      context 'when vulnerabilities is empty' do
        let(:vulnerabilities) { [] }

        it { is_expected.to be_valid }
      end

      context 'when vulnerabilities has a single valid license' do
        let(:vulnerabilities) { [info] }

        it { is_expected.to be_valid }
      end

      context 'when vulnerabilities has multiple valid license' do
        let(:vulnerabilities) { [info, critical] }

        it { is_expected.to be_valid }
      end

      context 'when id is missing' do
        let(:vulnerabilities) { [info.except(:id)] }

        it { is_expected.not_to be_valid }
      end

      context 'when id is not integer' do
        let(:vulnerabilities) { [info.merge(id: "1")] }

        it { is_expected.not_to be_valid }
      end

      context 'when name is missing' do
        let(:vulnerabilities) { [info.except(:name)] }

        it { is_expected.not_to be_valid }
      end

      context 'when name is an empty string' do
        let(:vulnerabilities) { [info.merge(name: "")] }

        it { is_expected.not_to be_valid }
      end

      context 'when url is missing' do
        let(:vulnerabilities) { [info.except(:url)] }

        it { is_expected.not_to be_valid }
      end

      context 'when url is not valid' do
        let(:vulnerabilities) { [info.merge(url: "invalid")] }

        it { is_expected.not_to be_valid }
      end

      context 'when severity is missing' do
        let(:vulnerabilities) { [info.except(:severity)] }

        it { is_expected.not_to be_valid }
      end

      context 'when severity matches the existing enum' do
        ::Enums::Vulnerability.severity_levels.each_key do |severity_level|
          context "with severity set to #{severity_level}" do
            let(:vulnerabilities) { [info.merge(severity: severity_level)] }

            it { is_expected.to be_valid }
          end
        end
      end

      context 'when severity does not match the existing enum' do
        let(:vulnerabilities) { [info.merge(severity: "invalid")] }

        it { is_expected.not_to be_valid }
      end
    end
  end

  describe '.filter_by_components scope' do
    let_it_be(:matching_occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }
    let_it_be(:non_matching_occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }

    it 'returns occurrences matching the given components' do
      expect(described_class.filter_by_components([matching_occurrence.component])).to eq([matching_occurrence])
    end

    it 'returns occurrences matching the given component ids' do
      expect(described_class.filter_by_components([matching_occurrence.component.id])).to eq([matching_occurrence])
    end
  end

  describe '.with_component_source_version_project_and_pipeline scope' do
    let_it_be(:occurrence) { create(:sbom_occurrence, component: create(:sbom_component)) }

    it 'pre-loads relations to avoid executing additional queries' do
      record = described_class.with_component_source_version_project_and_pipeline.first

      queries = ActiveRecord::QueryRecorder.new do
        record.component
        record.component_version
        record.source
        record.pipeline
        record.project
      end

      expect(queries.count).to be_zero
    end
  end

  describe '.filter_by_non_nil_component_version scope' do
    let_it_be(:matching_occurrence) { create(:sbom_occurrence) }
    let_it_be(:non_matching_occurrence) { create(:sbom_occurrence, component_version: nil) }

    it 'returns occurrences with a non-nil component_version' do
      expect(described_class.filter_by_non_nil_component_version).to eq([matching_occurrence])
    end
  end

  describe '.filter_by_cvs_enabled scope' do
    let_it_be(:project_with_cvs) { create(:project, :with_cvs) }
    let_it_be(:project_without_cvs) { create(:project) }

    let_it_be(:matching_occurrence) do
      create(:sbom_occurrence, component: create(:sbom_component), project: project_with_cvs)
    end

    let_it_be(:non_matching_occurrence) do
      create(:sbom_occurrence, component: create(:sbom_component), project: project_without_cvs)
    end

    it 'returns occurrences having a project where cvs is enabled' do
      expect(described_class.filter_by_cvs_enabled).to eq([matching_occurrence])
    end
  end

  describe '.order_by_id' do
    let_it_be(:first) { create(:sbom_occurrence) }
    let_it_be(:second) { create(:sbom_occurrence) }

    it 'returns records sorted by id' do
      expect(described_class.order_by_id).to eq([first, second])
    end
  end

  describe '.order_by_component_name' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence, component: create(:sbom_component, name: 'component_1')) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, component: create(:sbom_component, name: 'component_2')) }

    it 'returns records sorted by component name asc' do
      expect(described_class.order_by_component_name('asc').map(&:name)).to eq(%w[component_1 component_2])
    end

    it 'returns records sorted by component name desc' do
      expect(described_class.order_by_component_name('desc').map(&:name)).to eq(%w[component_2 component_1])
    end
  end

  describe '.order_by_package_name' do
    let_it_be(:occurrence_nuget) { create(:sbom_occurrence, packager_name: 'nuget') }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, packager_name: 'npm') }
    let_it_be(:occurrence_null) { create(:sbom_occurrence, source: nil) }

    subject(:relation) { described_class.order_by_package_name(order) }

    context 'when the sort order is ascending' do
      let(:order) { 'asc' }

      it 'returns records sorted by package name asc' do
        expect(relation.map(&:packager)).to eq(['npm', 'nuget', nil])
      end
    end

    context 'when the sort order is descending' do
      let(:order) { 'desc' }

      it 'returns records sorted by package name desc' do
        expect(relation.map(&:packager)).to eq([nil, 'nuget', 'npm'])
      end
    end
  end

  describe '.order_by_spdx_identifier' do
    let_it_be(:mit_occurrence) { create(:sbom_occurrence, :mit) }
    let_it_be(:apache_occurrence) { create(:sbom_occurrence, :apache_2) }
    let_it_be(:apache_and_mpl_occurrence) { create(:sbom_occurrence, :apache_2, :mpl_2) }
    let_it_be(:apache_and_mit_occurrence) { create(:sbom_occurrence, :apache_2, :mit) }
    let_it_be(:mit_and_mpl_occurrence) { create(:sbom_occurrence, :mit, :mpl_2) }

    subject(:relation) { described_class.order_by_spdx_identifier(order) }

    context 'when sorting in ascending order' do
      let(:order) { 'asc' }

      it 'returns the sorted records' do
        expect(relation.map(&:licenses)).to eq([
          apache_and_mit_occurrence.licenses,
          apache_and_mpl_occurrence.licenses,
          apache_occurrence.licenses,
          mit_and_mpl_occurrence.licenses,
          mit_occurrence.licenses
        ])
      end
    end

    context 'when sorting in descending order' do
      let(:order) { 'desc' }

      it 'returns the sorted records' do
        expect(relation.map(&:licenses)).to eq([
          mit_occurrence.licenses,
          mit_and_mpl_occurrence.licenses,
          apache_occurrence.licenses,
          apache_and_mpl_occurrence.licenses,
          apache_and_mit_occurrence.licenses
        ])
      end
    end
  end

  describe '.filter_by_component_names' do
    let_it_be(:occurrence_1) { create(:sbom_occurrence) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence) }

    it 'returns records filtered by component name' do
      expect(described_class.filter_by_component_names([occurrence_1.name])).to eq([occurrence_1])
    end
  end

  describe '.by_licenses' do
    subject { described_class.by_licenses(['MIT', 'MPL-2.0']) }

    let_it_be(:occurrence_1) { create(:sbom_occurrence, :apache_2) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, :mit) }
    let_it_be(:occurrence_3) { create(:sbom_occurrence, :mpl_2) }
    let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, :mpl_2) }

    it 'returns records filtered by license' do
      expect(subject).to match_array([occurrence_2, occurrence_3, occurrence_4])
    end
  end

  describe '.filter_by_package_managers' do
    let_it_be(:occurrence_nuget) { create(:sbom_occurrence, packager_name: 'nuget') }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, packager_name: 'npm') }
    let_it_be(:occurrence_null) { create(:sbom_occurrence, source: nil) }

    it 'returns records filtered by package name' do
      expect(described_class.filter_by_package_managers(%w[npm])).to eq([occurrence_npm])
    end

    context 'with empty array' do
      it 'returns no records' do
        expect(described_class.filter_by_package_managers([])).to eq([])
      end
    end
  end

  describe '.filter_by_search_with_component_and_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:occurrence_npm) { create(:sbom_occurrence, project: project) }
    let_it_be(:source_npm) { occurrence_npm.source }
    let_it_be(:component) { occurrence_npm.component }
    let_it_be(:source_bundler) { create(:sbom_source, packager_name: 'bundler', input_file_path: 'Gemfile.lock') }
    let_it_be(:occurrence_bundler) do
      create(:sbom_occurrence, source: source_bundler, component: component, project: project)
    end

    context 'with different search keywords' do
      using RSpec::Parameterized::TableSyntax

      where(:keyword, :occurrences) do
        'file'  | [ref(:occurrence_bundler)]
        'pack'  | [ref(:occurrence_npm)]
        'lock'  | [ref(:occurrence_npm), ref(:occurrence_bundler)]
        '_'     | []
      end

      with_them do
        it 'returns records filtered by search' do
          result = described_class.filter_by_search_with_component_and_group(keyword, component.id, group)

          expect(result).to eq(occurrences)
        end
      end
    end

    context 'with unrelated group' do
      let_it_be(:unrelated_group) { create(:group) }

      subject do
        described_class.filter_by_search_with_component_and_group('file', component.id, unrelated_group)
      end

      it { is_expected.to be_empty }
    end

    context 'with unrelated component' do
      let_it_be(:unrelated_component) { create(:sbom_component) }

      subject do
        described_class.filter_by_search_with_component_and_group('file', unrelated_component.id, group)
      end

      it { is_expected.to be_empty }
    end
  end

  describe ".with_licenses" do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject { described_class.with_licenses }

    context "without occurrences" do
      it { is_expected.to be_empty }
    end

    context "without a license" do
      let_it_be(:occurrence) { create(:sbom_occurrence, project: project) }

      it { is_expected.to be_empty }
    end

    context "with occurrences" do
      let_it_be(:occurrence_1) { create(:sbom_occurrence, :mit, project: project) }
      let_it_be(:occurrence_2) { create(:sbom_occurrence, :mpl_2, project: project) }
      let_it_be(:occurrence_3) { create(:sbom_occurrence, :apache_2, project: project) }
      let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, :mpl_2, project: project) }
      let_it_be(:occurrence_5) { create(:sbom_occurrence, :mit, :mpl_2, project: project) }
      let_it_be(:occurrence_6) { create(:sbom_occurrence, :apache_2, :mit, project: project) }
      let_it_be(:occurrence_7) { create(:sbom_occurrence, project: project) }

      it "returns an occurrence for each unique license" do
        expect(subject.pluck(:spdx_identifier)).to eq([
          "MIT",
          "MPL-2.0",
          "Apache-2.0",
          "Apache-2.0", "MPL-2.0",
          "MIT", "MPL-2.0",
          "Apache-2.0", "MIT"
        ])
      end
    end
  end

  describe '#name' do
    let(:component) { build(:sbom_component, name: 'rails') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates name to component' do
      expect(occurrence.name).to eq('rails')
    end
  end

  describe '#version' do
    let(:component_version) { build(:sbom_component_version, version: '6.1.6.1') }
    let(:occurrence) { build(:sbom_occurrence, component_version: component_version) }

    it 'delegates version to component_version' do
      expect(occurrence.version).to eq('6.1.6.1')
    end

    context 'when component_version is nil' do
      let(:occurrence) { build(:sbom_occurrence, component_version: nil) }

      it 'returns nil' do
        expect(occurrence.version).to be_nil
      end
    end
  end

  describe '#purl_type' do
    let(:component) { build(:sbom_component, purl_type: 'npm') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates purl_type to component' do
      expect(occurrence.purl_type).to eq('npm')
    end
  end

  describe '#component_type' do
    let(:component) { build(:sbom_component, component_type: 'library') }
    let(:occurrence) { build(:sbom_occurrence, component: component) }

    it 'delegates component_type to component' do
      expect(occurrence.component_type).to eq('library')
    end
  end

  describe 'source delegation' do
    let(:source_attributes) do
      {
        'category' => 'development',
        'input_file' => { 'path' => 'package-lock.json' },
        'source_file' => { 'path' => 'package.json' },
        'package_manager' => { 'name' => 'npm' },
        'language' => { 'name' => 'JavaScript' }
      }
    end

    let(:source) { build(:sbom_source, source: source_attributes) }
    let(:occurrence) { build(:sbom_occurrence, source: source) }

    describe '#packager' do
      subject(:packager) { occurrence.packager }

      it 'delegates packager to source' do
        expect(packager).to eq('npm')
      end

      context 'when source is nil' do
        let(:occurrence) { build(:sbom_occurrence, source: nil) }

        it { is_expected.to be_nil }
      end
    end

    describe '#location' do
      subject(:location) { occurrence.location }

      it 'returns expected location data' do
        expect(location).to eq(
          {
            blob_path: "/#{occurrence.project.full_path}/-/blob/#{occurrence.commit_sha}/#{source.input_file_path}",
            path: source.input_file_path,
            top_level: false,
            ancestors: nil
          }
        )
      end

      context 'when source is nil' do
        let(:occurrence) { build(:sbom_occurrence, source: nil) }

        it 'returns nil values' do
          expect(location).to eq(
            {
              blob_path: nil,
              path: nil,
              top_level: false,
              ancestors: nil
            }
          )
        end
      end
    end
  end
end
