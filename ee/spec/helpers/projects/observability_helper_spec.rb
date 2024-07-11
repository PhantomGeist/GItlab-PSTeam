# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe Projects::ObservabilityHelper, type: :helper, feature_category: :tracing do
  include Gitlab::Routing.url_helpers

  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, group: group) }

  describe '#observability_tracing_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        oauthUrl: Gitlab::Observability.oauth_url,
        provisioningUrl: Gitlab::Observability.provisioning_url(project),
        tracingUrl: Gitlab::Observability.tracing_url(project),
        servicesUrl: Gitlab::Observability.services_url(project),
        operationsUrl: Gitlab::Observability.operations_url(project)
      }.to_json

      expect(helper.observability_tracing_view_model(project)).to eq(expected_json)
    end
  end

  describe '#observability_tracing_details_model' do
    it 'generates the correct JSON' do
      expected_json = {
        oauthUrl: Gitlab::Observability.oauth_url,
        provisioningUrl: Gitlab::Observability.provisioning_url(project),
        tracingUrl: Gitlab::Observability.tracing_url(project),
        servicesUrl: Gitlab::Observability.services_url(project),
        operationsUrl: Gitlab::Observability.operations_url(project),
        traceId: "trace-id",
        tracingIndexUrl: namespace_project_tracing_index_path(project.group, project)
      }.to_json

      expect(helper.observability_tracing_details_model(project, "trace-id")).to eq(expected_json)
    end
  end

  describe '#observability_metrics_view_model' do
    it 'generates the correct JSON' do
      expected_json = {
        oauthUrl: Gitlab::Observability.oauth_url,
        provisioningUrl: Gitlab::Observability.provisioning_url(project),
        tracingUrl: Gitlab::Observability.tracing_url(project),
        servicesUrl: Gitlab::Observability.services_url(project),
        operationsUrl: Gitlab::Observability.operations_url(project)
      }.to_json

      expect(helper.observability_metrics_view_model(project)).to eq(expected_json)
    end
  end
end
