# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Deployments::UpdateEnvironmentService, feature_category: :continuous_delivery do
  include ::EE::GeoHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:deployment) { create(:deployment, :success, project: project) }

  subject { described_class.new(deployment) }

  describe '#execute' do
    it 'calls replicator to update Geo' do
      expect(project).to receive(:geo_handle_after_update).once

      subject.execute
    end

    it 'returns the deployment' do
      expect(subject.execute).to eq(deployment)
    end
  end
end
