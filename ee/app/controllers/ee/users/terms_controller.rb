# frozen_string_literal: true

module EE
  module Users
    module TermsController
      extend ActiveSupport::Concern

      prepended do
        include GoogleAnalyticsCSP
      end
    end
  end
end
