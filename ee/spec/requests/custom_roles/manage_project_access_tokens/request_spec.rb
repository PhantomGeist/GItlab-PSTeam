# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_dependency custom role', feature_category: :system_access do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, :in_group) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(user)
  end

  describe Projects::Settings::AccessTokensController do
    let_it_be(:role) { create(:member_role, :guest, namespace: project.group, manage_project_access_tokens: true) }
    let_it_be(:member) { create(:project_member, :guest, member_role: role, user: user, project: project) }

    describe 'GET /:namespace/:project/-/settings/access_tokens' do
      it 'user has access via custom role' do
        get project_settings_access_tokens_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    describe ProjectsController do
      it 'user has access via custom role' do
        get project_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Access Token')
      end
    end
  end
end
