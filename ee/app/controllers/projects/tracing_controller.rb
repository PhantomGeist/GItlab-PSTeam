# frozen_string_literal: true

module Projects
  class TracingController < Projects::ApplicationController
    include ::Observability::ContentSecurityPolicy

    feature_category :tracing

    before_action :authorize_read_tracing!

    def index; end

    def show
      @trace_id = params[:id]
    end
  end
end
