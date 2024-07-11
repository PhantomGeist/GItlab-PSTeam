# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::Dashboard, feature_category: :product_analytics_data_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:project) do
    create(:project, :repository,
      project_setting: build(:project_setting),
      group: group)
  end

  let_it_be(:config_project) do
    create(:project, :with_product_analytics_dashboard, group: group)
  end

  before do
    stub_licensed_features(
      product_analytics: true,
      project_level_analytics_dashboard: true,
      group_level_analytics_dashboard: true
    )
  end

  describe '.for' do
    context 'when resource is a project' do
      let(:resource_parent) { project }

      subject { described_class.for(container: resource_parent, user: user) }

      before do
        project.project_setting.update!(product_analytics_instrumentation_key: "key")
        allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
            'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
          }))
        end
      end

      it 'returns a collection of builtin dashboards' do
        expect(subject.size).to eq(3)
        expect(subject.map(&:title)).to match_array(['Audience', 'Behavior', 'Value Stream Dashboard'])
      end

      context 'when configuration project is set' do
        before do
          resource_parent.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'returns custom and builtin dashboards' do
          expect(subject).to be_a(Array)
          expect(subject.size).to eq(4)
          expect(subject.last).to be_a(described_class)
          expect(subject.last.title).to eq('Dashboard Example 1')
          expect(subject.last.slug).to eq('dashboard_example_1')
          expect(subject.last.description).to eq('North Star Metrics across all departments for the last 3 quarters.')
          expect(subject.last.schema_version).to eq('1')
        end
      end

      context 'when the dashboard file does not exist in the directory' do
        before do
          project.repository.create_file(
            project.creator,
            '.gitlab/analytics/dashboards/dashboard_example_1/project_dashboard_example_wrongly_named.yaml',
            File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
            message: 'test',
            branch_name: 'master'
          )
        end

        it 'excludes the dashboard from the list' do
          expect(subject.size).to eq(4)
        end
      end

      context 'when product analytics onboarding is incomplete' do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: nil)
        end

        it 'excludes product analytics dashboards' do
          expect(subject.size).to eq(2)
        end
      end
    end

    context 'when resource is a group' do
      let_it_be(:resource_parent) { group }

      subject { described_class.for(container: resource_parent, user: user) }

      it 'returns value stream dashboards' do
        expect(subject.size).to eq(1)
        expect(subject.map(&:title)).to match_array(['Value Stream Dashboard'])
      end

      context 'when configuration project is set' do
        before do
          resource_parent.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'returns custom and value stream dashboards' do
          expect(subject).to be_a(Array)
          expect(subject.size).to eq(2)
          expect(subject.map(&:title)).to match_array(['Value Stream Dashboard', 'Dashboard Example 1'])
        end
      end

      context 'when the dashboard file does not exist in the directory' do
        before do
          project.repository.create_file(
            project.creator,
            '.gitlab/analytics/dashboards/dashboard_example_1/group_dashboard_example_wrongly_named.yaml',
            File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
            message: 'test',
            branch_name: 'master'
          )
        end

        it 'excludes the dashboard from the list' do
          expect(subject.size).to eq(2)
        end
      end
    end

    context 'when resource is not a project or a group' do
      it 'raises error' do
        invalid_object = double

        error_message =
          "A group or project must be provided. Given object is RSpec::Mocks::Double type"
        expect { described_class.for(container: invalid_object, user: user) }
          .to raise_error(ArgumentError, error_message)
      end
    end
  end

  describe '#panels' do
    before do
      project.update!(analytics_dashboards_configuration_project: config_project, namespace: config_project.namespace)
    end

    subject { described_class.for(container: project, user: user).last.panels }

    it { is_expected.to be_a(Array) }

    it 'is expected to contain two panels' do
      expect(subject.size).to eq(2)
    end

    it 'is expected to contain a panel with the correct title' do
      expect(subject.first.title).to eq('Overall Conversion Rate')
    end

    it 'is expected to contain a panel with the correct grid attributes' do
      expect(subject.first.grid_attributes).to eq({ 'xPos' => 1, 'yPos' => 4, 'width' => 12, 'height' => 2 })
    end

    it 'is expected to contain a panel with the correct query overrides' do
      expect(subject.first.query_overrides).to eq({
        'timeDimensions' => {
          'dateRange' => ['2016-01-01', '2016-01-30'] # rubocop:disable Style/WordArray
        }
      })
    end
  end

  describe '#==' do
    let(:dashboard_1) { described_class.for(container: project, user: user).first }
    let(:dashboard_2) do
      described_class.new(
        title: 'a',
        description: 'b',
        schema_version: '1',
        panels: [],
        container: project,
        slug: 'test2',
        user_defined: true,
        config_project: project
      )
    end

    subject { dashboard_1 == dashboard_2 }

    it { is_expected.to be false }
  end

  describe '.value_stream_dashboard' do
    subject { described_class.value_stream_dashboard(project, config_project) }

    it 'returns the value stream dashboard' do
      dashboard = subject.first
      expect(dashboard).to be_a(described_class)
      expect(dashboard.title).to eq('Value Stream Dashboard')
      expect(dashboard.slug).to eq('value_stream_dashboard')
      expect(dashboard.description).to eq(
        'The Value Stream Dashboard allows all stakeholders from executives ' \
        'to individual contributors to identify trends, patterns, and ' \
        'opportunities for software development improvements.')
      expect(dashboard.schema_version).to eq(nil)
    end
  end
end
