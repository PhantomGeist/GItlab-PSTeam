# frozen_string_literal: true

module Vulnerabilities
  module Statistics
    class AdjustmentService
      TooManyProjectsError = Class.new(StandardError)

      UPSERT_SQL = <<~SQL
        INSERT INTO vulnerability_statistics
          (project_id, total, info, unknown, low, medium, high, critical, letter_grade, created_at, updated_at)
          (%{stats_sql})
        ON CONFLICT (project_id)
        DO UPDATE SET
          total = EXCLUDED.total,
          info = EXCLUDED.info,
          unknown = EXCLUDED.unknown,
          low = EXCLUDED.low,
          medium = EXCLUDED.medium,
          high = EXCLUDED.high,
          critical = EXCLUDED.critical,
          letter_grade = EXCLUDED.letter_grade,
          updated_at = EXCLUDED.updated_at
      SQL

      STATS_SQL = <<~SQL
        WITH project_ids AS (
          SELECT unnest(ARRAY[%{project_ids}]::bigint[]) AS project_id
        )
        SELECT
          project_ids.project_id AS project_id,
          COALESCE(severity_counts.total, 0) AS total,
          COALESCE(severity_counts.info, 0) AS info,
          COALESCE(severity_counts.unknown, 0) AS unknown,
          COALESCE(severity_counts.low, 0) AS low,
          COALESCE(severity_counts.medium, 0) AS medium,
          COALESCE(severity_counts.high, 0) AS high,
          COALESCE(severity_counts.critical, 0) AS critical,
          (
            CASE
            WHEN severity_counts.critical > 0 THEN
              #{Statistic.letter_grades['f']}
            WHEN severity_counts.high > 0 OR severity_counts.unknown > 0 THEN
              #{Statistic.letter_grades['d']}
            WHEN severity_counts.medium > 0 THEN
              #{Statistic.letter_grades['c']}
            WHEN severity_counts.low > 0 THEN
              #{Statistic.letter_grades['b']}
            ELSE
              #{Statistic.letter_grades['a']}
            END
          ) AS letter_grade,
          now() AS created_at,
          now() AS updated_at
        FROM
          project_ids
        LEFT OUTER JOIN(
          SELECT
            vulnerability_reads.project_id AS project_id,
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['info']}) as info,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['unknown']}) as unknown,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['low']}) as low,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['medium']}) as medium,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['high']}) as high,
            COUNT(*) FILTER (WHERE severity = #{Vulnerability.severities['critical']}) as critical
          FROM vulnerability_reads
          WHERE
            vulnerability_reads.project_id IN (%{project_ids}) AND
            vulnerability_reads.state IN (%{active_states})
          GROUP BY vulnerability_reads.project_id
        ) AS severity_counts ON severity_counts.project_id = project_ids.project_id
      SQL

      MAX_PROJECTS = 1_000

      def self.execute(project_ids)
        new(project_ids).execute
      end

      def initialize(project_ids)
        raise TooManyProjectsError, "Cannot adjust statistics for more than #{MAX_PROJECTS} projects" if project_ids.size > MAX_PROJECTS

        self.project_ids = project_ids.join(', ')
      end

      def execute
        connection.execute(upsert_sql)
      end

      private

      attr_accessor :project_ids

      delegate :connection, to: ApplicationRecord, private: true

      def upsert_sql
        UPSERT_SQL % { stats_sql: stats_sql }
      end

      def stats_sql
        STATS_SQL % { project_ids: project_ids, active_states: active_states }
      end

      def active_states
        Vulnerability.active_state_values.join(', ')
      end
    end
  end
end
