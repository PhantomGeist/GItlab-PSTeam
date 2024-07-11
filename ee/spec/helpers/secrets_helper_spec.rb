# frozen_string_literal: true

require "spec_helper"

RSpec.describe SecretsHelper, feature_category: :secrets_management do
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:group) { build_stubbed(:group) }

  describe '#project_secrets_app_data' do
    subject { helper.project_secrets_app_data(project) }

    it 'returns expected data' do
      expect(subject).to include({
        project_path: project.full_path,
        project_id: project.id
      })
    end
  end

  describe '#group_secrets_app_data' do
    subject { helper.group_secrets_app_data(group) }

    it 'returns expected data' do
      expect(subject).to include({
        group_path: group.full_path,
        group_id: group.id
      })
    end
  end
end
