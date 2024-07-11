# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectPresenter, feature_category: :consumables_cost_management do
  let(:user) { build_stubbed(:user) }
  let_it_be(:root_project) { create(:project, :public) } # rubocop:disable RSpec/FactoryBot/AvoidCreate

  describe '#storage_anchor_text' do
    let(:presenter) { described_class.new(project, current_user: user) }

    before do
      stub_application_setting(check_namespace_plan: true)
      stub_application_setting(namespace_storage_forks_cost_factor: 0.1)
    end

    context 'when project is a fork' do
      let_it_be_with_reload(:project) do
        # rubocop:disable RSpec/FactoryBot/AvoidCreate
        project_fork = create(:project, :public)
        fork_network = create(:fork_network, root_project: root_project)
        create(:fork_network_member,
          fork_network: fork_network,
          project: project_fork,
          forked_from_project: root_project)
        # rubocop:enable RSpec/FactoryBot/AvoidCreate
        project_fork
      end

      it 'returns storage anchor text with the cost factored storage size' do
        project.statistics.update!(storage_size: 10.megabytes)

        expected_text = '<strong class="project-stat-value">1 MiB</strong> Forked Project'
        expect(presenter.storage_anchor_data.label).to include expected_text
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(display_cost_factored_storage_size_on_project_pages: false)
        end

        it 'returns storage anchor text without cost factored storage size' do
          project.statistics.update!(storage_size: 10.megabytes)

          expected_text = '<strong class="project-stat-value">10 MiB</strong> Project Storage'
          expect(presenter.storage_anchor_data.label).to include expected_text
        end
      end
    end

    context 'when project is not a fork' do
      let(:project) { root_project }

      it 'returns storage anchor text with the full storage size' do
        project.statistics.update!(storage_size: 10.megabytes)

        expected_text = '<strong class="project-stat-value">10 MiB</strong> Project Storage'
        expect(presenter.storage_anchor_data.label).to include expected_text
      end
    end
  end
end
