# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Seeders::Ci::Catalog::ResourceSeeder, feature_category: :pipeline_composition do
  let_it_be(:admin) { create(:admin) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:seed_count) { 2 }
  let_it_be(:last_resource_id) { seed_count - 1 }

  let(:group_path) { group.path }

  subject(:seeder) { described_class.new(group_path: group_path, seed_count: seed_count) }

  before_all do
    group.add_owner(admin)
  end

  describe '#seed' do
    subject(:seed) { seeder.seed }

    context 'when the group does not exists' do
      let(:group_path) { 'nonexistent_group' }

      it 'skips seeding' do
        expect { seed }.not_to change { Project.count }
      end
    end

    context 'when project name already exists' do
      before do
        create(:project, namespace: group, name: "ci_seed_resource_0")
      end

      it 'skips that project creation and keeps seeding' do
        expect { seed }.to change { Project.count }.by(seed_count - 1)
      end
    end

    context 'when project.saved? fails' do
      before do
        project = build(:project, name: nil)

        allow_next_instance_of(::Projects::CreateService) do |service|
          allow(service).to receive(:execute).and_return(project)
        end
      end

      it 'does not modify the projects count' do
        expect { seed }.not_to change { Project.count }
      end
    end

    context 'when ci resource creation fails' do
      before do
        allow_next_instance_of(::Ci::Catalog::AddResourceService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'error'))
        end
      end

      it 'does not add a catalog resource' do
        expect { seed }.to change { Project.count }.by(seed_count)

        expect(group.projects.all?(&:catalog_resource)).to eq false
      end
    end

    it 'skips seeding a project if the project name already exists' do
      # We call the same command twice, as it means it would try to recreate
      # projects that were already created!
      expect { seed }.to change { group.projects.count }.by(seed_count)
      expect { seed }.to change { group.projects.count }.by(0)
    end

    it 'creates as many projects as specific in the argument' do
      expect { seed }.to change {
        group.projects.count
      }.by(seed_count)

      last_ci_resource = Project.last

      expect(last_ci_resource.name).to eq "ci_seed_resource_#{last_resource_id}"
    end

    it 'adds a README and a template.yml file to the projects' do
      seed
      project = group.projects.last
      default_branch = project.default_branch_or_main

      expect(project.repository.blob_at(default_branch, "README.md")).not_to be_nil
      expect(project.repository.blob_at(default_branch, "template.yml")).not_to be_nil
    end

    # This should be run again when fixing: https://gitlab.com/gitlab-org/gitlab/-/issues/429649
    xit 'creates projects with CI catalog resources' do
      expect { seed }.to change { Project.count }.by(seed_count)

      expect(group.projects.all?(&:catalog_resource)).to eq true
    end
  end
end
