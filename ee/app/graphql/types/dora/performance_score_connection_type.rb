# frozen_string_literal: true

module Types
  module Dora
    # rubocop: disable Graphql/AuthorizeTypes
    class PerformanceScoreConnectionType < GraphQL::Types::Relay::BaseConnection
      graphql_name 'DoraPerformanceScoreConnectionType'
      description 'Connection details for aggregated DORA metrics for a collection of projects'

      field :total_projects_count,
        GraphQL::Types::Int,
        null: false,
        description: 'Count of total projects.',
        resolver_method: :authorized_projects_count

      field :no_dora_data_projects_count,
        GraphQL::Types::Int,
        null: false,
        description: 'Count of projects without any DORA scores within the scope.',
        resolver_method: :no_dora_data_projects_count

      def authorized_projects_count
        context[:authorized_projects_count]
      end

      def no_dora_data_projects_count
        context[:projects_without_dora_data_count]
      end
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
