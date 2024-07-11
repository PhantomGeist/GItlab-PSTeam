# frozen_string_literal: true

module EE
  module Analytics
    module CycleAnalytics
      module IssueStageEvent
        extend ActiveSupport::Concern

        prepended do
          include Awardable

          has_one :epic_issue, primary_key: 'issue_id', foreign_key: 'issue_id' # rubocop: disable Rails/InverseOf

          scope :not_authored, ->(user_id) { where(author_id: nil).or(where.not(author_id: user_id)) }
          scope :without_weight, ->(weight) { where(weight: nil).or(where.not(weight: weight)) }
          scope :without_sprint_id, ->(sprint_id) { where(sprint_id: nil).or(where.not(sprint_id: sprint_id)) }
          scope :without_epic_id, ->(epic_id) do
            left_joins(:epic_issue)
              .merge(EpicIssue.where(epic_id: nil).or(EpicIssue.where.not(epic_id: epic_id)))
          end
          scope :not_assigned_to, ->(user) do
            assignees_class = ::IssueAssignee
            condition = assignees_class
              .where(user_id: user)
              .where(arel_table[:issue_id].eq(assignees_class.arel_table[:issue_id]))

            where(condition.arel.exists.not)
          end
        end
      end
    end
  end
end
