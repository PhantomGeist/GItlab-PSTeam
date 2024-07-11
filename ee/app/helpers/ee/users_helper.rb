# frozen_string_literal: true

module EE
  module UsersHelper
    extend ::Gitlab::Utils::Override

    override :display_public_email?
    def display_public_email?(user)
      return false if user.public_email.blank?
      return true unless user.provisioned_by_group

      !::Feature.enabled?(:hide_public_email_on_profile, user.provisioned_by_group)
    end

    override :impersonation_enabled?
    def impersonation_enabled?
      super && !::Gitlab::CurrentSettings.personal_access_tokens_disabled?
    end

    def users_sentence(users, link_class: nil)
      users.map { |user| link_to(user.name, user, class: link_class) }.to_sentence.html_safe
    end

    def user_badges_in_admin_section(user)
      super(user).tap do |badges|
        if !::Gitlab.com? && user.using_license_seat?
          it_s_you_index = badges.index { |badge| badge[:text] == "It's you!" } || -1

          badges.insert(it_s_you_index, { text: s_('AdminUsers|Is using seat'), variant: 'neutral' })
        end
      end
    end

    def trials_allowed?(user)
      return false unless user
      return false unless ::Gitlab::CurrentSettings.should_check_namespace_plan?

      Rails.cache.fetch(['users', user.id, 'trials_allowed?'], expires_in: 10.minutes) do
        !user.belongs_to_paid_namespace? && user.owns_group_without_trial?
      end
    end

    def user_enterprise_group_text(user)
      enterprise_group = user.user_detail.enterprise_group
      return unless enterprise_group

      group_info = link_to enterprise_group.name, admin_group_path(enterprise_group)
      user_enterprise_group = content_tag :li do
        concat content_tag(:span, _("Enterprise user of: "), class: "light")
        concat content_tag(:strong, group_info)
        gid_text = format(' (%{gid})', gid: enterprise_group.id)
        concat content_tag(:span, gid_text, class: "light")
      end

      user_enterprise_associated = content_tag :li do
        concat content_tag(:span, _("Enterprise user associated at: "), class: "light")
        concat content_tag(:strong, user.user_detail.enterprise_group_associated_at.to_fs(:medium))
      end

      user_enterprise_group + user_enterprise_associated
    end

    private

    override :preload_project_associations
    def preload_project_associations(projects)
      ActiveRecord::Associations::Preloader.new(records: projects, associations: :invited_groups).call
    end
  end
end
