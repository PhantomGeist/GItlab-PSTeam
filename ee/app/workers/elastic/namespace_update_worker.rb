# frozen_string_literal: true

module Elastic
  class NamespaceUpdateWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker
    prepend IndexingControl

    data_consistency :sticky
    feature_category :global_search

    def perform(id)
      return unless Gitlab::CurrentSettings.elasticsearch_indexing?

      namespace = Namespace.find(id)
      update_users_through_membership(namespace)
      update_epics(namespace) if namespace.group_namespace?
    end

    def update_users_through_membership(namespace)
      user_ids = case namespace.type
                 when 'Group'
                   group_and_descendants_user_ids(namespace)
                 when 'Project'
                   project_user_ids(namespace)
                 end

      return unless user_ids

      # rubocop:disable CodeReuse/ActiveRecord
      User.where(id: user_ids).find_in_batches do |batch_of_users|
        Elastic::ProcessBookkeepingService.track!(*batch_of_users)
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end

    def update_epics(namespace)
      Elastic::ProcessBookkeepingService.maintain_indexed_group_associations!(namespace)
    end

    def group_and_descendants_user_ids(namespace)
      ::Gitlab::Database.allow_cross_joins_across_databases(url:
        "https://gitlab.com/gitlab-org/gitlab/-/issues/422405") do
        namespace.self_and_descendants.flat_map(&:user_ids)
      end
    end

    def project_user_ids(namespace)
      project = namespace.project
      project.user_ids
    end
  end
end
