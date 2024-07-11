# frozen_string_literal: true

module Onboarding
  def self.user_onboarding_in_progress?(user)
    user.present? &&
      user.onboarding_in_progress? &&
      ::Onboarding::Status.enabled?
  end
end
