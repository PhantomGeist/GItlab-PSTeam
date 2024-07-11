# frozen_string_literal: true

module Gitlab
  module Geo
    module BatchCounter
      MAX_ALLOWED_LOOPS = 100_000

      def batch_count(relation, column = nil)
        # When the minimum and maximum range divided by the default batch size (100.000 records)
        # exceeds the maximum loops allowed (10.000), the counters return the fallback number (-1).
        # Passing in a high number to the max_allowed_loops parameter, turn off the max loop check.
        # This is required to avoid reaching an unwanted configuration while counting records in a
        # large table, e.g., job_artifact_registry.
        #
        # See issue: https://gitlab.com/gitlab-org/gitlab/-/issues/421213
        ::Gitlab::Database::BatchCounter.new(relation, column: column, max_allowed_loops: MAX_ALLOWED_LOOPS)
          .count
      end
    end
  end
end
