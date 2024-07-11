# frozen_string_literal: true

module Sbom
  class DependencyLicensesFinder
    MAXIMUM_LICENSES = 100

    def initialize(namespace:, params: {})
      @namespace = namespace
      @params = params
    end

    def execute
      namespace.sbom_licenses(limit: MAXIMUM_LICENSES)
    end

    private

    attr_reader :namespace, :params
  end
end
