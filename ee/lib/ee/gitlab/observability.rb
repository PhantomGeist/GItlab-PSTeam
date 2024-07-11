# frozen_string_literal: true

module EE
  module Gitlab
    module Observability
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      class_methods do
        def tracing_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/traces"
        end

        def services_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/services"
        end

        def operations_url(project)
          "#{::Gitlab::Observability.observability_url}/v3/query/#{project.id}/services/$SERVICE_NAME$/operations"
        end
      end
    end
  end
end
