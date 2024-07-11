# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::DeleteProjectWorker, feature_category: :global_search do
  let(:root_namespace_id) { 10 }
  let(:zoekt_node_id) { 55 }
  let(:project_id) { 128 }

  describe '#perform' do
    context 'when node_id is nil' do
      subject { described_class.new.perform(root_namespace_id, project_id) }

      context 'when node_id can be found' do
        before do
          allow(::Search::Zoekt::Node).to receive(:for_namespace).with(root_namespace_id: root_namespace_id).and_return(
            instance_double(::Search::Zoekt::Node, id: zoekt_node_id)
          )
        end

        it 'executes delete_zoekt_index!' do
          expect(::Gitlab::Search::Zoekt::Client).to receive(:delete)
                                  .with(node_id: zoekt_node_id, project_id: project_id)

          subject
        end
      end

      context 'when node_id could not be found' do
        before do
          allow(::Search::Zoekt::Node).to receive(:for_namespace)
            .with(root_namespace_id: root_namespace_id).and_return(nil)
        end

        it 'does not execute delete_zoekt_index!' do
          expect(::Gitlab::Search::Zoekt::Client).not_to receive(:delete)

          subject
        end
      end
    end

    context 'when node_id is set' do
      subject { described_class.new.perform(root_namespace_id, project_id, zoekt_node_id) }

      it 'executes delete_zoekt_index!' do
        expect(::Search::Zoekt::Node).not_to receive(:for_namespace)
        expect(::Gitlab::Search::Zoekt::Client).to receive(:delete)
                                .with(node_id: zoekt_node_id, project_id: project_id)

        subject
      end
    end

    context 'when zoekt indexing is disabled' do
      before do
        stub_feature_flags(index_code_with_zoekt: false)
      end

      it 'does nothing' do
        expect(::Gitlab::Search::Zoekt::Client).not_to receive(:delete)

        subject
      end
    end
  end
end
