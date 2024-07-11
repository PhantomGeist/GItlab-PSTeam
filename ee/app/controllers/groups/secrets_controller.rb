# frozen_string_literal: true

module Groups
  class SecretsController < Groups::ApplicationController
    feature_category :secrets_management
    urgency :low, [:index]

    layout 'group'

    before_action :authorize_view_secrets!
    before_action :check_secrets_enabled!

    private

    def authorize_view_secrets!
      render_404 unless can?(current_user, :developer_access, group)
    end

    def check_secrets_enabled!
      render_404 unless Feature.enabled?(:ci_tanukey_ui, group.root_ancestor)
    end
  end
end
