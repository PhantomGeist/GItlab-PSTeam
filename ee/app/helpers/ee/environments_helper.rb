# frozen_string_literal: true

module EE
  module EnvironmentsHelper
    extend ::Gitlab::Utils::Override

    def can_approve_deployment?(deployment)
      can?(current_user, :approve_deployment, deployment)
    end
  end
end
