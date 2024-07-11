# frozen_string_literal: true

# Support bulk delete
module Search
  module Wiki
    class ElasticDeleteGroupWikiWorker
      MAX_JOBS_PER_HOUR = 3600

      include ApplicationWorker

      data_consistency :delayed
      prepend ::Elastic::IndexingControl

      feature_category :global_search
      urgency :throttled
      idempotent!

      def perform(group_id, options = {})
        options = options.with_indifferent_access
        helper = Gitlab::Elastic::Helper.default
        helper.remove_wikis_from_the_standalone_index(group_id, 'Group', options[:namespace_routing_id])
      end
    end
  end
end
