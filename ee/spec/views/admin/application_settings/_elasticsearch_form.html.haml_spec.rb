# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_elasticsearch_form', feature_category: :global_search do
  let_it_be(:admin) { create(:admin) }

  let(:page) { Capybara::Node::Simple.new(rendered) }
  let(:pause_indexing) { false }
  let(:pending_migrations) { false }
  let(:elastic_reindexing_task) { build(:elastic_reindexing_task) }
  let(:projects_not_indexed) { [] }
  let(:projects_not_indexed_count) { 0 }

  before do
    assign(:application_setting, application_setting)
    assign(:elasticsearch_reindexing_task, elastic_reindexing_task)
    allow(view).to receive(:current_user) { admin }
    allow(view).to receive(:expanded) { true }
    assign(:projects_not_indexed, projects_not_indexed)
    assign(:projects_not_indexed_count, projects_not_indexed_count)
  end

  context 'es indexing' do
    let(:application_setting) { build(:application_setting) }
    let(:button_text) { 'Index all projects' }

    before do
      allow(Gitlab::CurrentSettings).to(receive(:elasticsearch_indexing?)).and_return(es_indexing)
      allow(Gitlab::CurrentSettings).to(receive(:elasticsearch_pause_indexing?)).and_return(pause_indexing)
      allow(Elastic::DataMigrationService).to(receive(:pending_migrations?)).and_return(pending_migrations)
    end

    context 'indexing is enabled' do
      let(:es_indexing) { true }

      it 'hides index button when indexing is disabled' do
        render

        expect(rendered).to have_css('a.btn-confirm', text: button_text)
      end

      it 'renders an enabled pause checkbox' do
        render

        expect(rendered).to have_css('input[id=application_setting_elasticsearch_pause_indexing]')
        expect(rendered).not_to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
      end

      context 'pending migrations' do
        using RSpec::Parameterized::TableSyntax

        let(:pending_migrations) { true }
        let(:migration) { Elastic::DataMigrationService.migrations.first }

        before do
          allow(Elastic::DataMigrationService).to receive(:pending_migrations).and_return([migration])
          allow(migration).to receive(:running?).and_return(running)
          allow(migration).to receive(:pause_indexing?).and_return(pause_indexing)
        end

        where(:running, :pause_indexing, :disabled) do
          false | false | false
          false | true  | false
          true  | false | false
          true  | true  | true
        end

        with_them do
          it 'renders pause checkbox with disabled set appropriately' do
            render

            if disabled
              expect(rendered).to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
            else
              expect(rendered).not_to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
            end
          end
        end
      end
    end

    context 'indexing is disabled' do
      let(:es_indexing) { false }

      it 'shows index button when indexing is enabled' do
        render

        expect(rendered).not_to have_css('a.btn-confirm', text: button_text)
      end

      it 'renders a disabled pause checkbox' do
        render

        expect(rendered).to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
      end
    end
  end

  context 'when elasticsearch_aws_secret_access_key is not set' do
    let(:application_setting) { build(:application_setting) }

    it 'has field with "AWS Secret Access Key" label and no value' do
      render
      expect(rendered).to have_field('AWS Secret Access Key', type: 'password')
      expect(page.find_field('AWS Secret Access Key').value).to be_blank
    end
  end

  context 'when number of shards is set' do
    let(:application_setting) { build(:application_setting, elasticsearch_worker_number_of_shards: 4) }

    it 'has field with "Number of shards for non-code indexing" label and correct value' do
      render
      expect(rendered).to have_field('Number of shards for non-code indexing')
      expect(page.find_field('Number of shards for non-code indexing').value).to eq('4')
    end
  end

  context 'when elasticsearch_aws_secret_access_key is set' do
    let(:application_setting) { build(:application_setting, elasticsearch_aws_secret_access_key: 'elasticsearch_aws_secret_access_key') }

    it 'has field with "Enter new AWS Secret Access Key" label and a masked value' do
      render
      expect(rendered).to have_field('Enter new AWS Secret Access Key', type: 'password')
      expect(page.find_field('Enter new AWS Secret Access Key').value).to eq(ApplicationSetting::MASK_PASSWORD)
    end
  end

  context 'zero-downtime elasticsearch reindexing' do
    let(:application_setting) { build(:application_setting) }

    before do
      assign(:last_elasticsearch_reindexing_task, task)
    end

    context 'when task is in progress' do
      let(:task) { build(:elastic_reindexing_task, state: :reindexing) }

      it 'renders a disabled pause checkbox' do
        render

        expect(rendered).to have_css('input[id=application_setting_elasticsearch_pause_indexing][disabled="disabled"]')
      end

      it 'renders a disabled trigger cluster reindexing link' do
        render

        expect(rendered).to have_button('Trigger cluster reindexing', disabled: true)
      end
    end

    context 'without extended details' do
      let(:task) { build(:elastic_reindexing_task) }

      it 'renders the task' do
        render

        expect(rendered).to include("Reindexing Status: #{task.state}")
        expect(rendered).not_to include("Task ID:")
        expect(rendered).not_to include("Error:")
        expect(rendered).not_to include("Expected documents:")
        expect(rendered).not_to include("Documents reindexed:")
      end
    end

    context 'with extended details' do
      let!(:task) { create(:elastic_reindexing_task, state: :reindexing, error_message: 'error-message') }
      let!(:subtask) { create(:elastic_reindexing_subtask, elastic_reindexing_task: task, documents_count_target: 5, documents_count: 10) }

      it 'renders the task information' do
        render

        expect(rendered).to include("Reindexing Status: #{task.state}")
        expect(rendered).to include("Error: #{task.error_message}")
        expect(rendered).to include("Expected documents: #{subtask.documents_count}")
        expect(rendered).to include("Documents reindexed: #{subtask.documents_count_target} (50.0%)")
      end
    end

    context 'with extended details, but without documents_count_target' do
      let!(:task) { create(:elastic_reindexing_task, state: :reindexing) }
      let!(:subtask) { create(:elastic_reindexing_subtask, elastic_reindexing_task: task, documents_count: 10) }

      it 'renders the task information' do
        render

        expect(rendered).to include("Reindexing Status: #{task.state}")
        expect(rendered).to include("Expected documents: #{subtask.documents_count}")
        expect(rendered).not_to include("Error:")
        expect(rendered).not_to include("Documents reindexed:")
      end
    end

    context 'when there are 0 documents expected' do
      let_it_be(:task) { create(:elastic_reindexing_task, state: :reindexing) }
      let_it_be(:subtask) { create(:elastic_reindexing_subtask, elastic_reindexing_task: task, documents_count_target: 0, documents_count: 0) }

      it 'renders 100% completed progress' do
        render

        expect(rendered).to include('Expected documents: 0')
        expect(rendered).to include('Documents reindexed: 0 (100%)')
      end
    end
  end

  context 'when there are elasticsearch indexed namespaces' do
    let(:application_setting) { build(:application_setting, elasticsearch_limit_indexing: true) }

    before do
      create(:elasticsearch_indexed_namespace)
      create(:elasticsearch_indexed_namespace)
      create(:elasticsearch_indexed_namespace)
    end

    it 'shows the input' do
      render
      expect(rendered).to have_selector('.js-namespaces-indexing-restrictions')
    end

    context 'when there are too many elasticsearch indexed namespaces' do
      before do
        create_list :elasticsearch_indexed_namespace, 60
      end

      it 'hides the input' do
        render
        expect(rendered).not_to have_selector('.js-namespaces-indexing-restrictions')
      end
    end
  end

  context 'when there are elasticsearch indexed projects' do
    let(:application_setting) { build(:application_setting, elasticsearch_limit_indexing: true) }

    before do
      create(:elasticsearch_indexed_project)
      create(:elasticsearch_indexed_project)
      create(:elasticsearch_indexed_project)
    end

    it 'shows the input' do
      render
      expect(rendered).to have_selector('.js-projects-indexing-restrictions')
    end

    context 'when there are too many elasticsearch indexed projects' do
      before do
        create_list :elasticsearch_indexed_project, 60
      end

      it 'hides the input' do
        render
        expect(rendered).not_to have_selector('.js-projects-indexing-restrictions')
      end
    end
  end

  context 'elasticsearch migrations' do
    let(:application_setting) { build(:application_setting) }

    it 'does not show the retry migration card' do
      render

      expect(rendered).not_to include('Elasticsearch migration halted')
      expect(rendered).not_to include('Retry migration')
    end

    context 'when Elasticsearch migration halted' do
      let(:migration) { Elastic::DataMigrationService.migrations.last }

      before do
        allow(Elastic::DataMigrationService).to receive(:halted_migrations?).and_return(true)
        allow(Elastic::DataMigrationService).to receive(:halted_migration).and_return(migration)
      end

      context 'when there is no reindexing' do
        it 'shows the retry migration card' do
          render

          expect(rendered).to include('Elasticsearch migration halted')
          expect(rendered).to have_css('a', text: 'Retry migration')
          expect(rendered).not_to have_css('a[disabled="disabled"]', text: 'Retry migration')
        end
      end

      context 'when there is a reindexing task in progress' do
        before do
          assign(:last_elasticsearch_reindexing_task, build(:elastic_reindexing_task))
        end

        it 'shows the retry migration card with retry button disabled' do
          render

          expect(rendered).to include('Elasticsearch migration halted')
          expect(rendered).to have_css('a[disabled="disabled"]', text: 'Retry migration')
        end
      end
    end

    context 'when elasticsearch is unreachable' do
      before do
        allow(Gitlab::Elastic::Helper.default).to receive(:ping?).and_return(false)
      end

      it 'does not show the retry migration card' do
        render

        expect(rendered).not_to include('Elasticsearch migration halted')
        expect(rendered).not_to include('Retry migration')
      end
    end
  end

  context 'indexing status' do
    let(:projects_not_indexed_max_shown) { 50 }
    let(:application_setting) { build(:application_setting) }

    before do
      assign(:initial_queue_size, initial_queue_size)
      assign(:incremental_queue_size, incremental_queue_size)
    end

    context 'when there are projects being indexed' do
      let(:initial_queue_size) { 10 }
      let(:incremental_queue_size) { 10 }

      context 'when there are projects in initial queue' do
        let(:initial_queue_size) { 20 }
        let(:incremental_queue_size) { 0 }

        it 'shows count of items in this queue' do
          render

          expect(rendered).to have_selector('[data-testid="initial_queue_size"]', text: '20')
        end

        it 'has a button leading to documentation' do
          render

          expect(rendered).to have_selector('[data-testid="initial_indexing_documentation"]', text: 'Documentation')
        end
      end

      context 'when there are projects in incremental queue' do
        let(:initial_queue_size) { 0 }
        let(:incremental_queue_size) { 30 }

        it 'shows count of items in this queue' do
          render

          expect(rendered).to have_selector('[data-testid="incremental_queue_size"]', text: '30')
        end

        it 'has a button leading to documentation' do
          render

          expect(rendered).to have_selector('[data-testid="incremental_indexing_documentation"]', text: 'Documentation')
        end
      end
    end

    context 'when there are projects not indexed' do
      context 'when there is 20 projects not indexed' do
        let(:namespace) { instance_double("Namespace", human_name: "Namespace 1") }
        let_it_be(:projects_not_indexed) { create_list(:project, 20, :repository) }
        let(:projects_not_indexed_count) { 20 }

        let(:initial_queue_size) { 10 }
        let(:incremental_queue_size) { 10 }

        before do
          assign(:projects_not_indexed, projects_not_indexed)
          assign(:initial_queue_size, initial_queue_size)
          assign(:incremental_queue_size, incremental_queue_size)
          assign(:projects_not_indexed_count, projects_not_indexed_count)

          render
        end

        it 'shows count of 20 projects not indexed' do
          expect(rendered).to have_selector('[data-testid="projects_not_indexed_size"]', text: '20')
        end

        it 'doesn’t show text “Only first 50 of not indexed projects is shown"' do
          expect(rendered).not_to include('Only first 50 of not indexed projects is shown')
        end

        it 'shows 20 items in the list .project-row' do
          expect(rendered).to have_selector('[data-testid="not_indexed_project_row"]', count: 20)
        end

        context 'when on gitlab.com don\'t show 20 not indexed projects', :saas do
          it 'does not shows the list' do
            expect(rendered).not_to have_selector('.indexing-projects-list')
          end

          it 'does not show the count of projects not indexed' do
            expect(rendered).not_to have_selector('[data-testid="projects_not_indexed_size"]')
          end
        end
      end

      context 'when there is 100 projects not indexed' do
        let(:namespace) { instance_double("Namespace", human_name: "Namespace 1") }
        let_it_be(:projects_not_indexed) { create_list(:project, 100, :repository) }
        let(:projects_not_indexed_count) { 100 }

        let(:initial_queue_size) { 10 }
        let(:incremental_queue_size) { 10 }

        before do
          assign(:projects_not_indexed, projects_not_indexed)
          assign(:initial_queue_size, initial_queue_size)
          assign(:incremental_queue_size, incremental_queue_size)
          assign(:projects_not_indexed_count, projects_not_indexed_count)

          render
        end

        it 'shows count of 100 projects not indexed' do
          expect(rendered).to have_selector('[data-testid="projects_not_indexed_size"]', text: '100')
        end

        it 'shows text “Only first 50 of not indexed projects is shown"' do
          expect(rendered).to have_selector('[data-testid="projects_not_indexed_max_shown"]', text: 'Only first 50 of not indexed projects is shown')
        end

        it 'shows 100 items in the list .project-row' do
          # Under real conditions this will never have 100 items
          # since we are limiting ElasticProjectsNotIndexedFinder items
          # but for this test we are mocking the @projects_not_indexed
          # directly so limit is not applied
          expect(rendered).to have_selector('[data-testid="not_indexed_project_row"]', count: 100)
        end

        context 'when on gitlab.com don\'t show any not indexed projects', :saas do
          it 'does not shows the list' do
            expect(rendered).not_to have_selector('.indexing-projects-list')
          end

          it 'does not show the count of projects not indexed' do
            expect(rendered).not_to have_selector('[data-testid="projects_not_indexed_size"]')
          end
        end
      end

      context 'when there is 0 projects not indexed' do
        let(:namespace) { instance_double("Namespace", human_name: "Namespace 1") }
        let_it_be(:projects_not_indexed) { [] }
        let(:projects_not_indexed_count) { 0 }

        let(:initial_queue_size) { 10 }
        let(:incremental_queue_size) { 10 }

        before do
          assign(:projects_not_indexed, projects_not_indexed)
          assign(:initial_queue_size, initial_queue_size)
          assign(:incremental_queue_size, incremental_queue_size)
          assign(:projects_not_indexed_count, projects_not_indexed_count)

          render
        end

        it 'shows count of 0 projects not indexed' do
          expect(rendered).to have_selector('[data-testid="projects_not_indexed_size"]', text: '0')
        end

        it 'does not show the list' do
          expect(rendered).not_to have_selector('.indexing-projects-list')
        end
      end
    end
  end
end
