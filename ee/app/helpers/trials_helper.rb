# frozen_string_literal: true

module TrialsHelper
  TRIAL_ONBOARDING_SOURCE_URLS = %w[about.gitlab.com docs.gitlab.com learn.gitlab.com].freeze

  def create_lead_form_data
    {
      submit_path: trials_path(
        step: GitlabSubscriptions::Trials::CreateService::LEAD, **params.permit(:namespace_id).merge(glm_params)
      ),
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      company_name: current_user.organization
    }.merge(
      params.permit(
        :first_name, :last_name, :company_name, :company_size, :phone_number, :country, :state
      ).to_h.symbolize_keys
    )
  end

  def create_company_form_data
    submit_params = glm_params.merge(passed_through_params.to_unsafe_h)
    {
      submit_path: users_sign_up_company_path(submit_params),
      first_name: current_user.first_name,
      last_name: current_user.last_name
    }
  end

  def should_ask_company_question?
    TRIAL_ONBOARDING_SOURCE_URLS.exclude?(glm_params[:glm_source])
  end

  def glm_params
    strong_memoize(:glm_params) do
      params.slice(:glm_source, :glm_content).to_unsafe_h
    end
  end

  def namespace_selector_data(namespace_create_errors)
    {
      any_trial_eligible_namespaces: any_trial_eligible_namespaces?.to_s,
      new_group_name: params[:new_group_name],
      items: namespace_options_for_listbox.to_json,
      initial_value: params[:namespace_id],
      namespace_create_errors: namespace_create_errors
    }
  end

  def glm_source
    ::Gitlab.config.gitlab.host
  end

  def trial_selection_intro_text
    if any_trial_eligible_namespaces?
      s_('Trials|You can apply your trial to a new group or an existing group.')
    else
      s_('Trials|Create a new group to start your GitLab Ultimate trial.')
    end
  end

  def show_trial_namespace_select?
    any_trial_eligible_namespaces?
  end

  def namespace_options_for_listbox
    group_options = trial_eligible_namespaces.map { |n| { text: n.name, value: n.id.to_s } }
    options = [
      {
        text: _('New'),
        options: [
          {
            text: _('Create group'),
            value: '0'
          }
        ]
      }
    ]

    options.push(text: _('Groups'), options: group_options) unless group_options.empty?

    options
  end

  private

  def passed_through_params
    params.slice(
      :trial,
      :role,
      :registration_objective,
      :jobs_to_be_done_other,
      :opt_in
    )
  end

  def trial_eligible_namespaces
    current_user.manageable_namespaces_eligible_for_trial
  end

  def any_trial_eligible_namespaces?
    trial_eligible_namespaces.any?
  end
end
