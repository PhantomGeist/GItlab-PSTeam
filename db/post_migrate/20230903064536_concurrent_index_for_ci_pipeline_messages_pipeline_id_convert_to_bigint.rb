# frozen_string_literal: true

class ConcurrentIndexForCiPipelineMessagesPipelineIdConvertToBigint < Gitlab::Database::Migration[2.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_ci_pipeline_messages_on_pipeline_id_convert_to_bigint"
  TABLE_NAME = :ci_pipeline_messages
  COLUMN_NAME = :pipeline_id_convert_to_bigint

  def up
    add_concurrent_index TABLE_NAME, COLUMN_NAME, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name TABLE_NAME, INDEX_NAME
  end
end
