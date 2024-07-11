# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MetricsController, feature_category: :metrics do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let(:path) { nil }
  let(:observability_metrics_ff) { true }

  subject do
    get path
    response
  end

  before do
    stub_licensed_features(metrics_observability: true)
    stub_feature_flags(observability_metrics: observability_metrics_ff)
    sign_in(user)
  end

  shared_examples 'metrics route request' do
    it_behaves_like 'observability csp policy' do
      before_all do
        project.add_reporter(user)
      end

      let(:tested_path) { path }
    end

    context 'when user does not have permissions' do
      before_all do
        project.add_guest(user)
      end

      it 'returns 404' do
        expect(subject).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user has permissions' do
      before_all do
        project.add_reporter(user)
      end

      it 'returns 200' do
        expect(subject).to have_gitlab_http_status(:ok)
      end

      context 'when feature is disabled' do
        let(:observability_metrics_ff) { false }

        it 'returns 404' do
          expect(subject).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET #index' do
    let(:path) { project_metrics_path(project) }

    it_behaves_like 'metrics route request'

    describe 'html response' do
      before_all do
        project.add_reporter(user)
      end

      it 'renders the js-metrics element correctly' do
        element = Nokogiri::HTML.parse(subject.body).at_css('#js-observability-metrics')

        expected_view_model = {
          oauthUrl: Gitlab::Observability.oauth_url,
          provisioningUrl: Gitlab::Observability.provisioning_url(project),
          tracingUrl: Gitlab::Observability.tracing_url(project),
          servicesUrl: Gitlab::Observability.services_url(project),
          operationsUrl: Gitlab::Observability.operations_url(project)
        }.to_json
        expect(element.attributes['data-view-model'].value).to eq(expected_view_model)
      end
    end
  end
end
