# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::EpicClassProxy, feature_category: :global_search do
  subject { described_class.new(Epic, use_separate_indices: true) }

  let(:query) { 'test' }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:public_group) { create(:group, :public) }
  let(:options_without_user) do
    {
      current_user: nil,
      public_and_internal_projects: false,
      order_by: nil,
      sort: nil,
      group_ids: [public_group.id],
      count_only: false
    }
  end

  let(:options) do
    {
      current_user: user,
      public_and_internal_projects: false,
      order_by: nil,
      sort: nil,
      group_ids: [group.id],
      count_only: false
    }
  end

  let(:elastic_search) { subject.elastic_search(query, options: options) }
  let(:response) do
    Elasticsearch::Model::Response::Response.new(Epic, Elasticsearch::Model::Searching::SearchRequest.new(Epic, '*'))
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_licensed_features(epics: true)
  end

  describe '#elastic_search' do
    context 'for anonymous user' do
      let(:options) { options_without_user }

      it 'performs anonymous epic search and returns correct results' do
        query_hash = hash_including(
          query: {
            bool: {
              filter: [
                { term: { type: hash_including(value: 'epic') } },
                { bool: { should: [
                  { term: { confidential: hash_including(value: false) } }
                ] } }
              ],
              must: [
                { simple_query_string: hash_including(fields: ['title^2', 'description'], query: query) }
              ]
            }
          }
        )
        expect(subject).to receive(:search).with(query_hash, anything).and_return(response)
        expect(elastic_search).to eq(response)
      end
    end

    it 'calls search with the correct arguments' do
      expect(subject).to receive(:search).with({ query: { match_none: {} }, size: 0 }, anything).and_return(response)

      expect(elastic_search).to eq(response)
    end

    context 'when the user is authorized to view the group' do
      before_all do
        group.add_guest(user)
      end

      it 'calls search with the correct arguments' do
        query_hash = hash_including(
          query: {
            bool: {
              filter: [
                { term: { type: hash_including(value: 'epic') } },
                { bool: { should: [{ prefix: { traversal_ids: hash_including(value: "#{group.id}-") } }] } },
                { bool: { should: [
                  { term: { confidential: hash_including(value: false) } }
                ] } }
              ],
              must: [
                { simple_query_string: hash_including(fields: ['title^2', 'description'], query: query) }
              ]
            }
          }
        )

        expect(subject).to receive(:search).with(query_hash, anything).and_return(response)

        expect(elastic_search).to eq(response)
      end
    end
  end

  describe '#find_groups_by_ids' do
    context 'when the group_ids array contains a group' do
      let_it_be(:group) { create(:group) }
      let(:options) { { group_ids: [group.id] } }

      it 'returns the group' do
        expect(subject.find_groups_by_ids(options)).to eq([group])
      end
    end

    context 'when the group_ids array does not contain a valid group id' do
      let(:options) { { group_ids: ['non_existent_group'] } }

      it 'returns an empty array' do
        expect(subject.find_groups_by_ids(options)).to eq([])
      end
    end

    context 'when the group_ids array is not passed' do
      let(:options) { {} }

      it 'returns an empty array' do
        expect(subject.find_groups_by_ids(options)).to eq([])
      end
    end
  end

  describe '#groups_filter' do
    let(:query_hash) { { query: { bool: { filter: [] } } } }
    let(:filters) { subject.groups_filter(query_hash)[:query][:bool][:filter] }
    let(:non_confidential_filter) { { term: { confidential: { _name: "confidential:false", value: false } } } }

    before do
      subject.instance_variable_set(:@current_user, user)
      subject.instance_variable_set(:@groups, [group])
    end

    context 'when the user is not allowed to read confidential epics for the top-level group' do
      it 'returns a filter for confidential: false' do
        expect(filters).to eq([{ bool: { should: [non_confidential_filter] } }])
      end

      context 'if the user is able to read confidential epics from a child group' do
        let_it_be(:child_group) { create(:group, :private, parent: group) }
        let(:confidential_filter) { { term: { confidential: { _name: "confidential:true", value: true } } } }
        let(:authorized_groups_filter) do
          { terms: { _name: "groups:can:read_confidential_epics", group_id: [child_group.id] } }
        end

        let(:confidential_and_groups_filter) { { bool: { filter: [confidential_filter, authorized_groups_filter] } } }

        before_all do
          child_group.add_owner(user)
        end

        it 'has a filter for either confidential:false OR (confidential:true AND group_id is authorized)' do
          expect(filters).to eq([{ bool: { should: [non_confidential_filter, confidential_and_groups_filter] } }])
        end
      end
    end

    describe 'routing' do
      before_all do
        group.add_owner(user)
      end
      it 'is equal to root_ancestor_id' do
        expect(subject.routing_options(options)).to eq({ routing: "group_#{group.root_ancestor.id}" })
      end
    end
  end
end
