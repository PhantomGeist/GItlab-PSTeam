# frozen_string_literal: true

module Projects
  class LearnGitlabController < Projects::ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include ::Onboarding::SetRedirect

    before_action :verify_onboarding_enabled!
    before_action :authenticate_user! # since it is skipped in inherited controller
    before_action :owner_access!, only: :onboarding
    before_action :verify_learn_gitlab_available!, only: :show

    helper_method :onboarding_status

    feature_category :onboarding
    urgency :low, [:show]

    def show; end

    def onboarding
      cookies[:confetti_post_signup] = true

      render layout: 'minimal'
    end

    private

    def verify_learn_gitlab_available!
      access_denied! unless ::Onboarding::LearnGitlab.available?(project.namespace, current_user)
    end

    def owner_access!
      access_denied! unless can?(current_user, :owner_access, project)
    end

    def onboarding_status
      ::Onboarding::Status.new(params, session, current_user)
    end
    strong_memoize_attr :onboarding_status
  end
end
