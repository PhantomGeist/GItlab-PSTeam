# frozen_string_literal: true

module Resolvers
  module ProductAnalytics
    class DashboardsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      calls_gitaly!
      authorizes_object!
      authorize :developer_access
      type [::Types::ProductAnalytics::DashboardType], null: true

      argument :slug, GraphQL::Types::String,
               required: false,
               description: 'Find by dashboard slug.'

      argument :category, ::Types::ProductAnalytics::CategoryEnum,
               required: false,
               description: 'Find by dashboard type.',
               default_value: ::Types::ProductAnalytics::StateEnum.values['ANALYTICS']

      def resolve(slug: nil, category: 'analytics')
        return object.product_analytics_dashboards(current_user) unless slug.present?

        category.nil? || category == 'analytics' ? [object.product_analytics_dashboard(slug, current_user)] : []
      end
    end
  end
end
