# frozen_string_literal: true

module Types
  module Analytics
    module CycleAnalytics
      class NegatedIssueFilterInputType < BaseInputObject
        graphql_name 'NegatedValueStreamAnalyticsIssueFilterInput'

        argument :assignee_usernames, [GraphQL::Types::String],
          required: false,
          description: Types::Issues::NegatedIssueFilterInputType.arguments['assigneeUsernames'].description

        argument :author_username, GraphQL::Types::String,
          required: false,
          description: Types::Issues::NegatedIssueFilterInputType.arguments['authorUsername'].description

        argument :milestone_title, GraphQL::Types::String,
          required: false,
          description: Types::Issues::NegatedIssueFilterInputType.arguments['milestoneTitle'].description

        argument :label_names, [GraphQL::Types::String],
          required: false,
          description: Types::Issues::NegatedIssueFilterInputType.arguments['labelName'].description

        argument :epic_id, ID,
          required: false,
          description: Types::Issues::NegatedIssueFilterInputType.arguments['epicId'].description

        argument :iteration_id, ID,
          required: false,
          description: Types::Issues::NegatedIssueFilterInputType.arguments['iterationId'].description

        argument :weight, GraphQL::Types::Int,
          required: false,
          description: Types::Issues::NegatedIssueFilterInputType.arguments['weight'].description

        argument :my_reaction_emoji, GraphQL::Types::String,
          required: false,
          description: Types::Issues::NegatedIssueFilterInputType.arguments['myReactionEmoji'].description
      end
    end
  end
end
