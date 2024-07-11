# frozen_string_literal: true

module Profiles
  class UsageQuotasController < Profiles::ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP

    feature_category :purchase
    urgency :low

    def index
      @hide_search_settings = true
      @namespace = current_user.namespace
    end
  end
end
