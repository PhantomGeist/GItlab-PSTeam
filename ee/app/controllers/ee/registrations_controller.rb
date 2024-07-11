# frozen_string_literal: true

module EE
  module RegistrationsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    prepended do
      include Arkose::ContentSecurityPolicy
      include RegistrationsTracking
      include ::Onboarding::SetRedirect
      include GoogleAnalyticsCSP
      include GoogleSyndicationCSP

      skip_before_action :check_captcha, if: -> { arkose_labs_enabled? }
      before_action only: [:new, :create] do
        push_frontend_feature_flag(:arkose_labs_signup_challenge)
      end
      before_action :ensure_can_remove_self, only: [:destroy]
    end

    override :create
    def create
      unless verify_arkose_labs_token
        flash[:alert] = _('Complete verification to sign up.')
        render action: 'new'
        return
      end

      super
    end

    override :destroy
    def destroy
      unless allow_account_deletion?
        redirect_to profile_account_path, status: :see_other, alert: s_('Profiles|Account deletion is not allowed.')
        return
      end

      super
    end

    private

    override :after_request_hook
    def after_request_hook(user)
      super

      log_audit_event(user)
    end

    override :set_resource_fields
    def set_resource_fields
      super

      custom_confirmation_instructions_service.set_token(save: false)

      start_onboarding(onboarding_first_step_path, resource)
    end

    override :set_blocked_pending_approval?
    def set_blocked_pending_approval?
      super || ::User.user_cap_reached?
    end

    override :identity_verification_enabled?
    def identity_verification_enabled?
      resource.identity_verification_enabled?
    end

    override :identity_verification_redirect_path
    def identity_verification_redirect_path
      identity_verification_path
    end

    override :send_custom_confirmation_instructions
    def send_custom_confirmation_instructions
      return unless resource.persisted? && identity_verification_enabled?

      custom_confirmation_instructions_service.send_instructions
    end

    def custom_confirmation_instructions_service
      ::Users::EmailVerification::SendCustomConfirmationInstructionsService.new(resource)
    end
    strong_memoize_attr :custom_confirmation_instructions_service

    def ensure_can_remove_self
      unless current_user&.can_remove_self?
        redirect_to profile_account_path,
          status: :see_other,
          alert: s_('Profiles|Account could not be deleted. GitLab was unable to verify your identity.')
      end
    end

    def log_audit_event(user)
      return unless user&.persisted?

      ::Gitlab::Audit::Auditor.audit({
        name: "registration_created",
        author: user,
        scope: user,
        target: user,
        target_details: user.username,
        message: _("Instance access request"),
        additional_details: {
          registration_details: user.registration_audit_details
        }
      })
    end

    override :registration_path_params
    def registration_path_params
      glm_tracking_params.to_h
    end

    def verify_arkose_labs_token
      return true unless arkose_labs_enabled?
      return false unless params[:arkose_labs_token].present?

      arkose_labs_verify_response.present?
    end

    def arkose_labs_verify_response
      result = Arkose::TokenVerificationService.new(session_token: params[:arkose_labs_token]).execute
      result.success? ? result.payload[:response] : nil
    end
    strong_memoize_attr :arkose_labs_verify_response

    def record_arkose_data
      return unless resource&.persisted?
      return unless arkose_labs_enabled?
      return unless arkose_labs_verify_response

      Arkose::RecordUserDataService.new(
        response: arkose_labs_verify_response,
        user: resource
      ).execute
    end

    override :arkose_labs_enabled?
    def arkose_labs_enabled?
      ::Feature.enabled?(:arkose_labs_signup_challenge) &&
        ::Arkose::Settings.enabled?(user: resource, user_agent: request.user_agent)
    end

    def allow_account_deletion?
      !License.feature_available?(:disable_deleting_account_for_users) ||
        ::Gitlab::CurrentSettings.allow_account_deletion?
    end
  end
end
