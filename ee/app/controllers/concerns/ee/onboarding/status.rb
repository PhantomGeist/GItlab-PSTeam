# frozen_string_literal: true

module EE
  module Onboarding
    module Status
      PRODUCT_INTERACTION = {
        free: 'Personal SaaS Registration',
        trial: 'SaaS Trial',
        automatic_trial: 'SaaS Trial - defaulted',
        invite: 'Invited User',
        lead: 'SaaS Registration'
      }.freeze

      TRACKING_LABEL = {
        free: 'free_registration',
        trial: 'trial_registration',
        invite: 'invite_registration'
      }.freeze

      module ClassMethods
        def enabled?
          ::Gitlab::Saas.feature_available?(:onboarding)
        end
      end

      def self.prepended(base)
        base.singleton_class.prepend ClassMethods
      end

      def continue_full_onboarding?
        !subscription? &&
          !invite? &&
          !oauth? &&
          enabled?
      end

      def joining_a_project?
        ::Gitlab::Utils.to_boolean(params[:joining_project], default: false)
      end

      def redirect_to_company_form?
        trial? || setup_for_company?
      end

      def invite?
        members.any?
      end

      def trial?
        enabled? && ::Gitlab::Utils.to_boolean(params[:trial], default: false)
      end

      def oauth?
        return false unless base_stored_user_location_path.present?

        base_stored_user_location_path.starts_with?(::Gitlab::Routing.url_helpers.oauth_authorization_path)
      end

      def tracking_label
        return TRACKING_LABEL[:trial] if trial?
        return TRACKING_LABEL[:invite] if invite?

        TRACKING_LABEL[:free]
      end

      def group_creation_tracking_label
        return TRACKING_LABEL[:trial] if trial_onboarding_flow? || trial?

        TRACKING_LABEL[:free]
      end

      def onboarding_tracking_label
        return TRACKING_LABEL[:trial] if trial_onboarding_flow?

        TRACKING_LABEL[:free]
      end

      def trial_onboarding_flow?
        # This only comes from the submission of the company form.
        # It is then passed around to creating group/project
        # and then back to welcome controller for the
        # continuous getting started action.
        ::Gitlab::Utils.to_boolean(params[:trial_onboarding_flow], default: false)
      end

      def setup_for_company?
        ::Gitlab::Utils.to_boolean(params.dig(:user, :setup_for_company), default: false)
      end

      def enabled?
        self.class.enabled?
      end

      def subscription?
        enabled? && base_stored_user_location_path == ::Gitlab::Routing.url_helpers.new_subscriptions_path
      end

      def iterable_product_interaction
        if invite?
          PRODUCT_INTERACTION[:invite]
        else
          PRODUCT_INTERACTION[:free]
        end
      end

      def company_lead_product_interaction
        if trial?
          PRODUCT_INTERACTION[:trial]
        else
          PRODUCT_INTERACTION[:automatic_trial]
        end
      end

      def eligible_for_iterable_trigger?
        return false if trial?
        # The invite check coming first matters now in the case of a welcome form with company params
        # being received when the user is really an invite.
        # This covers the case for user being added to a group after they register, but
        # before they finish the welcome step.
        return true if invite?
        # skip company page because it already sends request to CustomersDot
        return false if redirect_to_company_form?

        # regular registration
        continue_full_onboarding?
      end

      def stored_user_location
        # side effect free look at devise store_location_for(:user)
        session['user_return_to']
      end

      private

      attr_reader :params, :session

      def base_stored_user_location_path
        return unless stored_user_location

        URI.parse(stored_user_location).path
      end
    end
  end
end
