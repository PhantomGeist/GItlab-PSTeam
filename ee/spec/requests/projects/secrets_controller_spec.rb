# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::SecretsController, type: :request, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group_project) { create(:project, namespace: root_group) }
  let_it_be(:group_subgroup) { create(:group, parent: root_group) }
  let_it_be(:group_subgroup_project) { create(:project, namespace: group_subgroup) }

  shared_examples 'renders the project secrets index template' do
    it do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template('projects/secrets/index')
    end
  end

  shared_examples 'returns a "not found" response' do
    it do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /:namespace/:project/-/secrets' do
    subject(:request) { get project_secrets_url(project), params: { project_id: project.to_param } }

    before_all do
      root_group.add_owner(user)
    end

    before do
      sign_in(user)
    end

    context 'when feature flag "ci_tanukey_ui" is enabled for the root group' do
      before do
        stub_feature_flags(ci_tanukey_ui: root_group)
      end

      context 'on the secrets page for a project in the group' do
        let(:project) { group_project }

        it_behaves_like 'renders the project secrets index template'
      end

      context 'on the secrets page for a project in a subgroup in the group' do
        let(:project) { group_subgroup_project }

        it_behaves_like 'renders the project secrets index template'
      end
    end

    context 'when feature flag "ci_tanukey_ui" is enabled for a subgroup' do
      before do
        stub_feature_flags(ci_tanukey_ui: group_subgroup)
      end

      context 'on the secrets page for a project outside of the subgroup' do
        let(:project) { group_project }

        it_behaves_like 'returns a "not found" response'
      end

      context 'on the secrets page for a project in the subgroup' do
        let(:project) { group_subgroup_project }

        it_behaves_like 'returns a "not found" response'
      end
    end

    context 'when feature flag "ci_tanukey_ui" is disabled' do
      let(:project) { group_project }

      before do
        stub_feature_flags(ci_tanukey_ui: false)
      end

      it_behaves_like 'returns a "not found" response'
    end
  end
end
