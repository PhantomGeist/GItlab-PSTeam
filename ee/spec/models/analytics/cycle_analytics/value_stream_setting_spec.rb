# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::ValueStreamSetting, type: :model, feature_category: :value_stream_management do
  let_it_be(:value_stream_setting) { create(:cycle_analytics_value_stream_setting) }

  describe 'associations' do
    it { is_expected.to belong_to(:value_stream) }
  end

  describe 'validations' do
    it {
      is_expected.not_to allow_value(Array.new(described_class::MAX_PROJECT_IDS_FILTER + 1, 1))
        .for(:project_ids_filter)
        .with_message('Maximum projects allowed in the filter is 100')
    }

    it { is_expected.to allow_value(Array.new(described_class::MAX_PROJECT_IDS_FILTER, 1)).for(:project_ids_filter) }
  end

  it 'persists project ids filter' do
    value_stream_setting =
      create(:cycle_analytics_value_stream_setting, project_ids_filter: [1, 2, 3])

    expect(value_stream_setting.project_ids_filter).to eq([1, 2, 3])
  end
end
