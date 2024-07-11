# frozen_string_literal: true

module EE
  module Gitlab
    module Saas
      extend ActiveSupport::Concern

      MissingFeatureError = Class.new(StandardError)

      FEATURES =
        %i[
          ai_vertex_embeddings
          marketing_google_tag_manager
          purchases_additional_minutes
          onboarding
          search_indexing_status
          subscriptions_trials
        ].freeze

      CONFIG_FILE_ROOT = 'ee/config/saas_features'

      class_methods do
        def feature_available?(feature)
          raise MissingFeatureError, 'Feature does not exist' unless FEATURES.include?(feature)

          enabled?
        end

        def enabled?
          # Use existing checks initially. We can allow it only in this place and remove it anywhere else.
          # eventually we can change its implementation like using an ENV variable for each instance
          # or any other method that people can't mess with.
          ::Gitlab.com? # rubocop:disable Gitlab/AvoidGitlabInstanceChecks
        end

        def feature_file_path(feature)
          Rails.root.join(CONFIG_FILE_ROOT, "#{feature}.yml")
        end
      end
    end
  end
end
