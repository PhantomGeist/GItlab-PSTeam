# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::ProjectsSearch, feature_category: :global_search do
  subject do
    Class.new do
      include Elastic::ProjectsSearch

      def id
        1
      end

      def es_id
        1
      end

      def pending_delete?
        false
      end

      def project_feature
        ProjectFeature.new
      end

      def root_namespace
        Namespace.new
      end
    end.new
  end

  describe '#maintain_elasticsearch_create' do
    it 'calls track!' do
      expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).and_return(true)

      subject.maintain_elasticsearch_create
    end
  end

  describe '#maintain_elasticsearch_update' do
    using RSpec::Parameterized::TableSyntax

    where(:attribute_updated, :indexing_expected) do
      :archived         | true
      :name             | false
      :visibility_level | true
    end

    with_them do
      it 'initiates repository reindexing when attributes change for when indexing is expected' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.and_return(true)

        if indexing_expected
          expect(::ElasticCommitIndexerWorker).to receive(:perform_async).and_return(true)
          expect(::ElasticWikiIndexerWorker).to receive(:perform_async).and_return(true)
        else
          expect(::ElasticCommitIndexerWorker).not_to receive(:perform_async)
          expect(::ElasticWikiIndexerWorker).not_to receive(:perform_async)
        end

        subject.maintain_elasticsearch_update(updated_attributes: [attribute_updated])
      end
    end
  end

  describe '#maintain_elasticsearch_destroy' do
    it 'calls delete worker' do
      expect(ElasticDeleteProjectWorker).to receive(:perform_async)
      expect(Search::Zoekt::DeleteProjectWorker).to receive(:perform_async)

      subject.maintain_elasticsearch_destroy
    end
  end
end
