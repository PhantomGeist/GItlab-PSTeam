import { s__ } from '~/locale';
import {
  MT_MERGE_STRATEGY,
  MTWPS_MERGE_STRATEGY,
  MWCP_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';

export default {
  computed: {
    statusText() {
      const { mergeTrainsCount, autoMergeStrategy } = this.state;

      if (autoMergeStrategy === MT_MERGE_STRATEGY) {
        return s__('mrWidget|Added to the merge train by %{merge_author}');
      }
      if (autoMergeStrategy === MTWPS_MERGE_STRATEGY && mergeTrainsCount === 0) {
        return s__(
          'mrWidget|Set by %{merge_author} to start a merge train when the pipeline succeeds',
        );
      }
      if (autoMergeStrategy === MTWPS_MERGE_STRATEGY && mergeTrainsCount !== 0) {
        return s__(
          'mrWidget|Set by %{merge_author} to be added to the merge train when the pipeline succeeds',
        );
      }
      if (autoMergeStrategy === MWCP_MERGE_STRATEGY) {
        return s__(
          'mrWidget|Set by %{merge_author} to be merged automatically when all merge checks pass',
        );
      }

      return s__(
        'mrWidget|Set by %{merge_author} to be merged automatically when the pipeline succeeds',
      );
    },
    cancelButtonText() {
      if (this.state.autoMergeStrategy === MT_MERGE_STRATEGY) {
        return s__('mrWidget|Remove from merge train');
      }

      return s__('mrWidget|Cancel auto-merge');
    },
  },
};
