# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalyticsHelpers, feature_category: :product_analytics_data_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  describe '#product_analytics_enabled?' do
    subject { project.product_analytics_enabled? }

    where(:licensed, :flag, :outcome) do
      false | false | false
      true | false | false
      false | true | false
      true | true | true
    end

    with_them do
      before do
        stub_feature_flags(product_analytics_dashboards: flag)
        stub_licensed_features(product_analytics: licensed)
      end

      it { is_expected.to eq(outcome) }
    end
  end

  describe '#product_analytics_dashboards' do
    it 'returns nothing if product analytics disabled' do
      stub_licensed_features(product_analytics: false)
      expect(project.product_analytics_dashboards(user)).to be_empty
    end

    context 'with configuration project' do
      let_it_be(:config_project) { create(:project, :with_product_analytics_dashboard, group: group) }

      before do
        stub_licensed_features(product_analytics: true)
        project.update!(analytics_dashboards_configuration_project: config_project)
      end

      it 'includes configuration project dashboards' do
        expect(project.product_analytics_dashboards(user)).not_to be_empty
      end
    end

    context 'without configuration project' do
      before do
        stub_licensed_features(product_analytics: true)
        project.project_setting.update!(product_analytics_instrumentation_key: "key")
        allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
            'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
          }))
        end
      end

      it 'includes built in dashboards' do
        expect(project.product_analytics_dashboards(user).map(&:title))
          .to match_array(%w[Audience Behavior])
      end

      context 'when product analytics onboarding is incomplete' do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: nil)
        end

        it 'is empty' do
          expect(project.product_analytics_dashboards(user)).to be_empty
        end
      end
    end
  end

  describe '#product_analytics_funnels' do
    subject { create(:project, :with_product_analytics_funnel).product_analytics_funnels }

    context 'when the feature is not available' do
      before do
        stub_licensed_features(product_analytics: false)
      end

      it { is_expected.to be_empty }
    end

    context 'when the feature is available' do
      before do
        stub_licensed_features(product_analytics: true)
      end

      it { is_expected.to contain_exactly(a_kind_of(::ProductAnalytics::Funnel)) }

      context 'when the project has defined a configuration project' do
        let_it_be(:configuration_project) { create(:project, :with_product_analytics_funnel, group: group) }

        before do
          project.update!(analytics_dashboards_configuration_project: configuration_project)
        end

        it 'returns the funnels from the configuration project' do
          expect(project.product_analytics_funnels.first.config_project).to eq(configuration_project)
        end
      end
    end
  end

  describe '#product_analytics_dashboard' do
    context 'when product analytics is disabled' do
      before do
        stub_licensed_features(product_analytics: false)
      end

      it 'returns nil' do
        expect(project.product_analytics_dashboard('test', user)).to be_nil
      end
    end

    context 'when product analytics is available' do
      before do
        stub_feature_flags(product_analytics_dashboards: true)
        stub_licensed_features(product_analytics: true)
      end

      context 'when the project has defined a configuration project' do
        let_it_be(:configuration_project) { create(:project, :with_product_analytics_dashboard, group: group) }

        before do
          project.update!(analytics_dashboards_configuration_project: configuration_project)
        end

        context 'when the requested dashboard exists' do
          let(:slug) { 'dashboard_example_1' }

          it 'returns the dashboard with the given slug' do
            expect(project.product_analytics_dashboard(slug, user).container).to eq(project)
            expect(project.product_analytics_dashboard(slug, user).config_project).to eq(configuration_project)
          end
        end

        context 'when the requested dashboard does not exist' do
          let(:slug) { 'Dashboard Example 1800' }

          it 'returns nil' do
            expect(project.product_analytics_dashboard(slug, user)).to be_nil
          end
        end
      end
    end
  end
end
