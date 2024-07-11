# frozen_string_literal: true

module Projects
  module ObservabilityHelper
    def observability_metrics_view_model(project)
      generate_model(project)
    end

    def observability_tracing_view_model(project)
      generate_model(project)
    end

    def observability_tracing_details_model(project, trace_id)
      generate_model(project) do |model|
        model[:traceId] = trace_id
        model[:tracingIndexUrl] = namespace_project_tracing_index_path(project.group, project)
      end
    end

    private

    def generate_model(project)
      model = shared_model(project)

      yield model if block_given?

      ::Gitlab::Json.generate(model)
    end

    def shared_model(project)
      {
        oauthUrl: ::Gitlab::Observability.oauth_url,
        provisioningUrl: ::Gitlab::Observability.provisioning_url(project),
        tracingUrl: ::Gitlab::Observability.tracing_url(project),
        servicesUrl: ::Gitlab::Observability.services_url(project),
        operationsUrl: ::Gitlab::Observability.operations_url(project)
      }
    end
  end
end
