# frozen_string_literal: true

module Projects
  class MetricsController < Projects::ApplicationController
    include ::Observability::ContentSecurityPolicy

    feature_category :metrics

    before_action :authorize_read_observability_metrics!

    def index; end
  end
end
