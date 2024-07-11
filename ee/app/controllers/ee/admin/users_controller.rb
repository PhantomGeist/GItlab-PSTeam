# frozen_string_literal: true

# rubocop:disable Gitlab/ModuleWithInstanceVariables
module EE
  module Admin
    module UsersController
      extend ::Gitlab::Utils::Override

      def identity_verification_exemption
        if @user.create_identity_verification_exemption
          redirect_to [:admin, @user], notice: _('Identity verification exemption has been created.')
        else
          redirect_to [:admin, @user], alert: _('Something went wrong. Unable to create identity verification exemption.')
        end
      end

      def destroy_identity_verification_exemption
        if @user.destroy_identity_verification_exemption
          redirect_to [:admin, @user], notice: _('Identity verification exemption has been removed.')
        else
          redirect_to [:admin, @user], alert: _('Something went wrong. Unable to remove identity verification exemption.')
        end
      end

      def reset_runners_minutes
        user

        ::Ci::Minutes::ResetUsageService.new(@user.namespace).execute
        redirect_to [:admin, @user], notice: _('User pipeline minutes were successfully reset.')
      end

      def card_match
        return render_404 unless ::Gitlab.com?

        credit_card_validation = user.credit_card_validation

        if credit_card_validation.present?
          @similar_credit_card_validations = credit_card_validation.similar_records.page(params[:page]).per(100)
        else
          redirect_to [:admin, @user], notice: _('No credit card data for matching')
        end
      end

      private

      override :users_with_included_associations
      def users_with_included_associations(users)
        super.includes(:oncall_schedules, :escalation_policies, :user_highest_role, :elevated_members) # rubocop: disable CodeReuse/ActiveRecord
      end

      override :log_impersonation_event
      def log_impersonation_event
        super

        log_audit_event
      end

      override :unlock_user
      def unlock_user
        update_user do
          user.unlock_access!(unlocked_by: current_user)
        end
      end

      override :prepare_user_for_update
      def prepare_user_for_update(user)
        super

        user.skip_enterprise_user_email_change_restrictions!
      end

      def log_audit_event
        ::AuditEvents::UserImpersonationEventCreateWorker.perform_async(current_user.id, user.id, request.remote_ip, 'started', DateTime.current)
      end

      def allowed_user_params
        super + [
          namespace_attributes: [
            :id,
            :shared_runners_minutes_limit,
            gitlab_subscription_attributes: [:hosted_plan_id]
          ],
          custom_attributes_attributes: [:id, :value]
        ]
      end
    end
  end
end
