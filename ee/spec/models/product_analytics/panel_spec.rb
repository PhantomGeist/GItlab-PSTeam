# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::Panel, feature_category: :product_analytics_data_management do
  let_it_be(:project) { create(:project, :with_product_analytics_dashboard) }
  let_it_be(:user) { create(:user) }

  subject { project.product_analytics_dashboard('dashboard_example_1', user).panels.first.visualization }

  before do
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(product_analytics_dashboards: true)
    project.project_setting.update!(product_analytics_instrumentation_key: "key")
    allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
      allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
        'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
      }))
    end
  end

  it 'returns the correct object' do
    expect(subject.type).to eq('LineChart')
    expect(subject.options)
      .to eq({ 'xAxis' => { 'name' => 'Time', 'type' => 'time' }, 'yAxis' => { 'name' => 'Counts' } })
    expect(subject.data['type']).to eq('Cube')
  end
end
