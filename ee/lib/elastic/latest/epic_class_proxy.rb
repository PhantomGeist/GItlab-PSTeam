# frozen_string_literal: true

module Elastic
  module Latest
    class EpicClassProxy < ApplicationClassProxy
      include Elastic::Latest::Routing

      attr_reader :groups, :current_user, :options

      def elastic_search(query, options: {})
        @current_user = options[:current_user]
        @options = options
        @groups = find_groups_by_ids(options)

        query_hash = if !groups.empty? || current_user&.can_read_all_resources?
                       query_hash = basic_query_hash(%w[title^2 description], query, options)
                       traversal_ids = if options[:search_scope] == 'global'
                                         groups.map { |g| g.root_ancestor.elastic_namespace_ancestry }.uniq
                                       else
                                         groups.map(&:elastic_namespace_ancestry)
                                       end

                       unless current_user&.can_read_all_resources? && options[:search_scope] == 'global'
                         query_hash = traversal_ids_ancestry_filter(query_hash, traversal_ids, options)
                       end

                       query_hash = groups_filter(query_hash)
                       apply_sort(query_hash, options)
                     elsif options[:search_scope] == 'global'
                       # For Global Search we can show all the public epics
                       query_hash = basic_query_hash(%w[title^2 description], query, options)
                       public_visbility_filter(query_hash)
                     else
                       match_none
                     end

        search(query_hash, options)
      end

      def find_groups_by_ids(options)
        group_ids = options[:group_ids]
        groups = Group.id_in(group_ids)
        groups.select { |group| Ability.allowed?(current_user, :read_epic, group) }
      end

      def groups_and_descendants
        @groups_and_descendants ||= groups.flat_map(&:self_and_descendants)
      end

      def match_none
        {
          query: { match_none: {} },
          size: 0
        }
      end

      def groups_filter(query_hash)
        group_ids = groups_user_can_read_confidential_epics.map(&:id)
        shoulds = [
          { term: { confidential: { value: false, _name: 'confidential:false' } } }
        ]

        if group_ids.any?
          shoulds << {
            bool: {
              filter: [
                {
                  term: { confidential: { value: true, _name: 'confidential:true' } }
                },
                {
                  terms: { group_id: group_ids, _name: 'groups:can:read_confidential_epics' }
                }
              ]
            }
          }
        end

        query_hash[:query][:bool][:filter] << { bool: { should: shoulds } }

        query_hash
      end

      def public_visbility_filter(query_hash)
        add_filter(query_hash, :query, :bool, :filter) do
          { term: { visibility_level: { value: ::Gitlab::VisibilityLevel::PUBLIC } } }
        end
      end

      def groups_user_can_read_confidential_epics
        Group.groups_user_can(groups_and_descendants, current_user, :read_confidential_epic)
      end

      def routing_options(options)
        groups = find_groups_by_ids(options)

        return {} if options[:search_scope] == 'global' || groups.blank?

        root_namespace_id = groups[0].root_ancestor.id

        { routing: "group_#{root_namespace_id}" }
      end

      def preload_indexing_data(relation)
        relation = relation.preload_for_indexing
        groups = relation.map(&:group)
        Preloaders::GroupRootAncestorPreloader.new(groups).execute

        relation
      end
    end
  end
end
