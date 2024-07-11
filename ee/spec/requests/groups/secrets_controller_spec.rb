# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SecretsController, type: :request, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group_subgroup) { create(:group, parent: root_group) }
  let_it_be(:group_subgroup_subgroup) { create(:group, parent: group_subgroup) }

  shared_examples 'renders the group secrets index template' do
    it do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template('groups/secrets/index')
    end
  end

  shared_examples 'returns a "not found" response' do
    it do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /groups/:group/-/secrets' do
    subject(:request) { get group_secrets_url(root_group), params: { group_id: root_group.to_param } }

    before_all do
      root_group.add_owner(user)
    end

    before do
      login_as(user)
    end

    context 'when feature flag "ci_tanukey_ui" is enabled for the root group' do
      before do
        stub_feature_flags(ci_tanukey_ui: root_group)
      end

      context 'on the secrets page for the group' do
        let(:group) { root_group }

        it_behaves_like 'renders the group secrets index template'
      end

      context 'on the secrets page for a subgroup' do
        let(:group) { group_subgroup }

        it_behaves_like 'renders the group secrets index template'
      end

      context 'on the secrets page for a subgroup of the subgroup' do
        let(:group) { group_subgroup_subgroup }

        it_behaves_like 'renders the group secrets index template'
      end
    end

    context 'when feature flag "ci_tanukey_ui" is enabled for a subgroup' do
      before do
        stub_feature_flags(ci_tanukey_ui: group_subgroup)
      end

      context 'on the secrets page for a group outside of the subgroup' do
        let(:group) { root_group }

        it_behaves_like 'returns a "not found" response'
      end

      context 'on the secrets page for the subgroup' do
        let(:group) { group_subgroup }

        it_behaves_like 'returns a "not found" response'
      end

      context 'on the secrets page for a group in the subgroup' do
        let(:group) { group_subgroup_subgroup }

        it_behaves_like 'returns a "not found" response'
      end
    end

    context 'when feature flag "ci_tanukey_ui" is disabled' do
      before do
        stub_feature_flags(ci_tanukey_ui: false)
      end

      context 'on the secrets page for the group' do
        let(:group) { root_group }

        it_behaves_like 'returns a "not found" response'
      end

      context 'on the secrets page for the subgroup' do
        let(:group) { group_subgroup }

        it_behaves_like 'returns a "not found" response'
      end

      context 'on the secrets page for a group in the subgroup' do
        let(:group) { group_subgroup_subgroup }

        it_behaves_like 'returns a "not found" response'
      end
    end
  end
end
