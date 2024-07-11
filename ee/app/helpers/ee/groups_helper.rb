# frozen_string_literal: true

module EE
  module GroupsHelper
    extend ::Gitlab::Utils::Override

    def size_limit_message_for_group(group)
      show_lfs = group.lfs_enabled? ? 'including LFS files' : ''

      "Max size for repositories within this group #{show_lfs}. Can be overridden inside each project. For no limit, enter 0. To inherit the global value, leave blank."
    end

    override :can_admin_service_accounts?
    def can_admin_service_accounts?(group)
      Ability.allowed?(current_user, :admin_service_accounts, group)
    end

    override :remove_group_message
    def remove_group_message(group)
      return super unless group.licensed_feature_available?(:adjourned_deletion_for_projects_and_groups)
      return super if group.marked_for_deletion?
      return super unless group.adjourned_deletion?

      date = permanent_deletion_date(Time.now.utc)

      _("The contents of this group, its subgroups and projects will be permanently removed after %{deletion_adjourned_period} days on %{date}. After this point, your data cannot be recovered.") %
        { date: date, deletion_adjourned_period: deletion_adjourned_period }
    end

    def immediately_remove_group_message(group)
      message = _('This action will %{strongOpen}permanently remove%{strongClose} %{codeOpen}%{group}%{codeClose} %{strongOpen}immediately%{strongClose}.')

      html_escape(message) % {
        group: group.path,
        strongOpen: '<strong>'.html_safe,
        strongClose: '</strong>'.html_safe,
        codeOpen: '<code>'.html_safe,
        codeClose: '</code>'.html_safe
      }
    end

    def permanent_deletion_date(date)
      (date + deletion_adjourned_period.days).strftime('%F')
    end

    def deletion_adjourned_period
      ::Gitlab::CurrentSettings.deletion_adjourned_period
    end

    def show_discover_group_security?(group)
      !!current_user &&
        ::Gitlab.com? &&
        !group.licensed_feature_available?(:security_dashboard) &&
        can?(current_user, :admin_group, group)
    end

    def show_group_activity_analytics?
      can?(current_user, :read_group_activity_analytics, @group)
    end

    def show_product_purchase_success_alert?
      !params[:purchased_product].blank?
    end

    def group_seats_usage_quota_app_data(group)
      pending_members_page_path = group.user_cap_available? ? pending_members_group_usage_quotas_path(group) : nil
      pending_members_count = ::Member.in_hierarchy(group).with_state("awaiting").count

      {
        namespace_id: group.id,
        namespace_name: group.name,
        full_path: group.full_path,
        seat_usage_export_path: group_seat_usage_path(group, format: :csv),
        pending_members_page_path: pending_members_page_path,
        pending_members_count: pending_members_count,
        add_seats_href: add_seats_url(group),
        has_no_subscription: group.has_free_or_no_subscription?.to_s,
        max_free_namespace_seats: ::Namespaces::FreeUserCap.dashboard_limit,
        explore_plans_path: group_billings_path(group),
        enforcement_free_user_cap_enabled: ::Namespaces::FreeUserCap::Enforcement.new(group).enforce_cap?.to_s
      }
    end

    def code_suggestions_usage_app_data(group)
      data = { full_path: group.full_path }

      return data unless ::Feature.enabled?(:cs_connect_with_sales, group)

      data.merge(code_suggestions_hand_raise_props(group))
    end

    def hand_raise_props(namespace, glm_content:, product_interaction: 'Hand Raise PQL')
      {
        namespace_id: namespace.id,
        user_name: current_user.username,
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        company_name: current_user.organization,
        glm_content: glm_content,
        product_interaction: product_interaction,
        create_hand_raise_lead_path: subscriptions_hand_raise_leads_path
      }
    end

    def code_suggestions_hand_raise_props(namespace)
      hand_raise_props(
        namespace,
        glm_content: 'code-suggestions',
        product_interaction: 'Requested Contact-Code Suggestions Add-On')
        .merge(track_action: 'click_button', track_label: 'code_suggestions_hand_raise_lead_form')
        .merge(button_attributes: { 'data-testid': 'code_suggestions_hand_raise_lead_button' }.to_json)
    end

    def show_code_suggestions_tab?(group)
      return false unless ::Feature.enabled?(:hamilton_seat_management, group)

      ::Gitlab.com? && !group.has_free_or_no_subscription?
    end

    def show_product_analytics_usage_quota_tab?(group)
      return false unless ::Feature.enabled?(:product_analytics_usage_quota, group)

      can?(current_user, :read_product_analytics, group)
    end

    def saml_sso_settings_generate_helper_text(display_none:, text:)
      content_tag(:span, text, class: ['js-helper-text', 'gl-clearfix', ('gl-display-none' if display_none)])
    end

    def group_transfer_app_data(group)
      {
        full_path: group.full_path
      }
    end

    override :enabled_git_access_protocol_options_for_group
    def enabled_git_access_protocol_options_for_group(group)
      return super unless ::Feature.enabled?(:enforce_ssh_certificates, group)
      return super unless group.licensed_feature_available?(:ssh_certificates)

      ssh_certificates_label = [[_("Only SSH Certificates"), "ssh_certificates"]]

      case ::Gitlab::CurrentSettings.enabled_git_access_protocol
      when nil, ""
        super + ssh_certificates_label
      when 'ssh_certificates'
        ssh_certificates_label
      else
        super
      end
    end
  end
end
