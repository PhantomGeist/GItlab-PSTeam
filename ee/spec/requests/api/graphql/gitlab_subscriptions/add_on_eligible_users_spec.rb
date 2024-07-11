# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.namespace.addOnEligibleUsers', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:code_suggestions) { create(:gitlab_subscription_add_on) }

  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions) }
  let(:query_add_on_purchase_ids) { [global_id_of(add_on_purchase)] }

  let(:query_fields) do
    query_graphql_field(:nodes, {}, [
      'id',
      query_graphql_field(:add_on_assignments, { add_on_purchase_ids: query_add_on_purchase_ids }, [
        query_graphql_field(:nodes, {}, [
          query_graphql_field(:add_on_purchase, {}, %w[id name])
        ])
      ])
    ])
  end

  context 'when the user is not eligible to admin add-on purchases on the namespace' do
    let(:query) do
      graphql_query_for(
        :namespace, { full_path: add_on_purchase.namespace.full_path },
        query_graphql_field(:addOnEligibleUsers, { add_on_type: :CODE_SUGGESTIONS }, query_fields)
      )
    end

    before do
      add_on_purchase.namespace.add_developer(current_user)
    end

    it 'returns no eligible users' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at['namespace']).to eq('addOnEligibleUsers' => nil)
      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist or you don't " \
                                       "have permission to perform this action")
    end
  end

  context 'when the requested namespace is not a root one' do
    let(:subgroup) { create(:group, parent: create(:group)) }

    let(:query) do
      graphql_query_for(
        :namespace, { full_path: subgroup.full_path },
        query_graphql_field(:addOnEligibleUsers, { add_on_type: :CODE_SUGGESTIONS }, query_fields)
      )
    end

    before do
      subgroup.add_owner(current_user)
    end

    it 'returns an error message and no eligible users' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at['namespace']).to eq('addOnEligibleUsers' => nil)
      expect_graphql_errors_to_include('Add on eligible users can only be queried on a root namespace')
    end
  end

  context 'when the current user is authorised to view the requested purchase ID' do
    let_it_be(:guest) { create(:user, name: 'Guest Group User') }
    let_it_be(:developer) { create(:user, name: 'Developer Group User') }

    before_all do
      add_on_purchase.namespace.add_owner(current_user)
      add_on_purchase.namespace.add_guest(guest)
      add_on_purchase.namespace.add_developer(developer)

      create(:gitlab_subscription_user_add_on_assignment, user: current_user, add_on_purchase: add_on_purchase)
      create(:gitlab_subscription_user_add_on_assignment, user: guest, add_on_purchase: add_on_purchase)
      create(:gitlab_subscription_user_add_on_assignment, user: developer, add_on_purchase: add_on_purchase)
    end

    context 'when the :hamilton_seat_management FF is disabled' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:addOnEligibleUsers, { add_on_type: :CODE_SUGGESTIONS }, query_fields)
        )
      end

      before do
        stub_feature_flags(hamilton_seat_management: false)
      end

      it 'returns an empty collection' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes)).to match_array([])
      end
    end

    context 'when there are search args' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(
            :addOnEligibleUsers,
            { add_on_type: :CODE_SUGGESTIONS, search: 'Group User' },
            query_fields
          )
        )
      end

      it 'returns the add on eligible users and their assignments, filtered by search term, ordered by ID' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes))
          .to eq([
            {
              'id' => global_id_of(developer).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            },
            {
              'id' => global_id_of(guest).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            }
          ])
      end
    end

    context 'when there are no search args' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:addOnEligibleUsers, { add_on_type: :CODE_SUGGESTIONS }, query_fields)
        )
      end

      it 'returns all the add on eligible users and their assignments' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes)).to match_array([
          {
            'id' => global_id_of(current_user).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(guest).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(developer).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          }
        ])
      end
    end

    context 'when the current user is only eligible to view a subset of assignments' do
      let(:add_on_purchase_1) { create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions) }
      let(:add_on_purchase_2) { create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions) }

      let(:query_add_on_purchase_ids) do
        [global_id_of(add_on_purchase), global_id_of(add_on_purchase_1), global_id_of(add_on_purchase_1)]
      end

      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:addOnEligibleUsers, { add_on_type: :CODE_SUGGESTIONS }, query_fields)
        )
      end

      before do
        add_on_purchase_1.namespace.add_owner(current_user)
        add_on_purchase_2.namespace.add_guest(current_user) # guest users can't admin add-on purchases

        create(:gitlab_subscription_user_add_on_assignment, user: guest, add_on_purchase: add_on_purchase_1)
        create(:gitlab_subscription_user_add_on_assignment, user: developer, add_on_purchase: add_on_purchase_2)
      end

      it 'only returns the authorised one' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes)).to match_array([
          {
            'id' => global_id_of(current_user).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(guest).to_s,
            'addOnAssignments' => {
              'nodes' => match_array([
                expected_add_on_purchase_data(add_on_purchase),
                expected_add_on_purchase_data(add_on_purchase_1)
              ])
            }
          },
          {
            'id' => global_id_of(developer).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          }
        ])
      end
    end

    context 'when there are multiple add-on eligible users' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:add_on_eligible_users, { add_on_type: :CODE_SUGGESTIONS }, query_fields)
        )
      end

      it "avoids N+1 database queries", :request_store do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(3)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        additional_user = create(:user)
        add_on_purchase.namespace.add_guest(additional_user)
        create(:gitlab_subscription_user_add_on_assignment, user: additional_user, add_on_purchase: add_on_purchase)

        expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control)
        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(4)
      end
    end

    context 'when selecting for multiple add on purchases' do
      let(:other_add_on_purchase) { create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions) }

      let(:query_add_on_purchase_ids) do
        [global_id_of(add_on_purchase), global_id_of(other_add_on_purchase)]
      end

      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:add_on_eligible_users, { add_on_type: :CODE_SUGGESTIONS }, query_fields)
        )
      end

      before do
        other_add_on_purchase.namespace.add_owner(current_user)
      end

      it "avoids N+1 database queries", :request_store do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(3)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create(:gitlab_subscription_user_add_on_assignment, user: current_user, add_on_purchase: other_add_on_purchase)

        expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control)
        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(4)
      end
    end
  end

  def expected_add_on_purchase_data(expected_add_on_purchase)
    {
      'addOnPurchase' => { 'id' => global_id_of(expected_add_on_purchase).to_s, 'name' => 'CODE_SUGGESTIONS' }
    }
  end
end
