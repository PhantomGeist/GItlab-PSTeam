# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchase, feature_category: :saas_provisioning do
  subject { build(:gitlab_subscription_add_on_purchase) }

  describe 'associations' do
    it { is_expected.to belong_to(:add_on).with_foreign_key(:subscription_add_on_id).inverse_of(:add_on_purchases) }
    it { is_expected.to belong_to(:namespace).optional(true) }

    it do
      is_expected.to have_many(:assigned_users)
        .class_name('GitlabSubscriptions::UserAddOnAssignment').inverse_of(:add_on_purchase)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:add_on) }
    it { is_expected.to validate_presence_of(:expires_on) }

    context 'when validating namespace presence' do
      context 'when on .com', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        it { is_expected.to validate_presence_of(:namespace) }
      end

      context 'when not on .com' do
        it { is_expected.not_to validate_presence_of(:namespace) }
      end
    end

    it { is_expected.to validate_uniqueness_of(:subscription_add_on_id).scoped_to(:namespace_id) }
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than_or_equal_to(1) }

    it { is_expected.to validate_presence_of(:purchase_xid) }
    it { is_expected.to validate_length_of(:purchase_xid).is_at_most(255) }
  end

  describe 'scopes' do
    shared_context 'with add-on purchases' do
      let_it_be(:code_suggestions_add_on) { create(:gitlab_subscription_add_on) }

      let_it_be(:expired_code_suggestion_purchase_as_owner) do
        create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: code_suggestions_add_on)
      end

      let_it_be(:active_code_suggestion_purchase_as_guest) do
        create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions_add_on)
      end

      let_it_be(:active_code_suggestion_purchase_as_reporter) do
        create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions_add_on)
      end

      let_it_be(:active_code_suggestion_purchase_as_developer) do
        create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions_add_on)
      end

      let_it_be(:active_code_suggestion_purchase_as_maintainer) do
        create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions_add_on)
      end

      let_it_be(:active_code_suggestion_purchase_unrelated) do
        create(:gitlab_subscription_add_on_purchase, add_on: code_suggestions_add_on)
      end

      let_it_be(:user) { create(:user) }

      before do
        expired_code_suggestion_purchase_as_owner.namespace.add_owner(user)
        active_code_suggestion_purchase_as_guest.namespace.add_guest(user)
        active_code_suggestion_purchase_as_reporter.namespace.add_reporter(user)
        active_code_suggestion_purchase_as_developer.namespace.add_developer(user)
        active_code_suggestion_purchase_as_maintainer.namespace.add_maintainer(user)
      end
    end

    describe '.active' do
      include_context 'with add-on purchases'

      subject(:active_purchases) { described_class.active }

      it 'returns all the purchases that are not expired' do
        expect(active_purchases).to match_array(
          [
            active_code_suggestion_purchase_as_guest, active_code_suggestion_purchase_as_reporter,
            active_code_suggestion_purchase_as_developer, active_code_suggestion_purchase_as_maintainer,
            active_code_suggestion_purchase_unrelated
          ]
        )
      end
    end

    describe '.by_add_on_name' do
      subject(:by_name_purchases) { described_class.by_add_on_name(name) }

      include_context 'with add-on purchases'

      context 'when name is: code_suggestions' do
        let(:name) { 'code_suggestions' }

        it 'returns all the purchases related to code_suggestions' do
          expect(by_name_purchases).to match_array(
            [
              expired_code_suggestion_purchase_as_owner, active_code_suggestion_purchase_as_guest,
              active_code_suggestion_purchase_as_reporter, active_code_suggestion_purchase_as_developer,
              active_code_suggestion_purchase_as_maintainer, active_code_suggestion_purchase_unrelated
            ]
          )
        end
      end

      context 'when name is set to anything else' do
        let(:name) { 'foo-bar' }

        it 'returns empty collection' do
          expect(by_name_purchases).to eq([])
        end
      end
    end

    describe '.for_code_suggestions' do
      subject(:code_suggestion_purchases) { described_class.for_code_suggestions }

      include_context 'with add-on purchases'

      it 'returns all the purchases related to code_suggestions' do
        expect(code_suggestion_purchases).to match_array(
          [
            expired_code_suggestion_purchase_as_owner, active_code_suggestion_purchase_as_guest,
            active_code_suggestion_purchase_as_reporter, active_code_suggestion_purchase_as_developer,
            active_code_suggestion_purchase_as_maintainer, active_code_suggestion_purchase_unrelated
          ]
        )
      end
    end

    describe '.for_user' do
      subject(:user_purchases) { described_class.for_user(user) }

      include_context 'with add-on purchases'

      it 'returns all the non-guest purchases related to the user top level namespaces' do
        expect(user_purchases).to match_array(
          [
            expired_code_suggestion_purchase_as_owner, active_code_suggestion_purchase_as_reporter,
            active_code_suggestion_purchase_as_developer, active_code_suggestion_purchase_as_maintainer
          ]
        )
      end
    end

    describe '.requiring_assigned_users_refresh' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
      let_it_be(:add_on_purchase_refreshed_nil) { create(:gitlab_subscription_add_on_purchase, add_on: add_on) }
      let_it_be(:add_on_purchase_fresh) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.hour.ago)
      end

      let_it_be(:add_on_purchase_stale) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 21.hours.ago)
      end

      it 'returns correct add_on_purchases' do
        result = [
          add_on_purchase_refreshed_nil,
          add_on_purchase_stale
        ]

        expect(described_class.requiring_assigned_users_refresh(3))
          .to match_array(result)
      end

      it 'accepts limit param' do
        expect(described_class.requiring_assigned_users_refresh(1).size).to eq 1
      end
    end
  end

  describe '.next_candidate_requiring_assigned_users_refresh' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:add_on_purchase_fresh) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.hour.ago)
    end

    subject(:next_candidate) { described_class.next_candidate_requiring_assigned_users_refresh }

    context 'when there are stale records' do
      let_it_be(:add_on_purchase_stale) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 21.hours.ago)
      end

      it 'returns the stale record' do
        expect(next_candidate).to eq(add_on_purchase_stale)
      end

      context 'when there is stale records with nil refreshed_at' do
        it 'returns record with nil refreshed_at as next candidate' do
          result = create(:gitlab_subscription_add_on_purchase, add_on: add_on)

          expect(next_candidate).to eq(result)
        end
      end

      context 'when there is stale record with earlier refreshed_at' do
        it 'returns record with earlier refreshed_at as next candidate' do
          result = create(
            :gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.day.ago
          )

          expect(next_candidate).to eq(result)
        end
      end
    end

    it 'returns nil when there are no stale records' do
      expect(next_candidate).to eq(nil)
    end
  end

  describe '#already_assigned?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    let(:user) { create(:user) }

    subject { add_on_purchase.already_assigned?(user) }

    context 'when the user has been already assigned' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end

      it { is_expected.to eq(true) }
    end

    context 'when user is not already assigned' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#active?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject { add_on_purchase.active? }

    it { is_expected.to eq(true) }

    context 'when subscription has expired' do
      it { travel_to(add_on_purchase.expires_on + 1.day) { is_expected.to eq(false) } }
    end
  end

  describe '#expired?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject { add_on_purchase.expired? }

    it { is_expected.to eq(false) }

    context 'when subscription has expired' do
      it { travel_to(add_on_purchase.expires_on + 1.day) { is_expected.to eq(true) } }
    end
  end

  describe '#delete_ineligible_user_assignments_in_batches!' do
    let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    let_it_be(:user_1) { create(:user) }
    let_it_be(:user_2) { create(:user) }

    subject(:result) { add_on_purchase.delete_ineligible_user_assignments_in_batches! }

    context 'with assigned_users records' do
      before do
        add_on_purchase.assigned_users.create!(user: user_1)
        add_on_purchase.assigned_users.create!(user: user_2)
      end

      it 'removes only ineligible user assignments' do
        add_on_purchase.namespace.add_guest(user_1) # user_1 still eligible

        expect(add_on_purchase.reload.assigned_users.count).to eq(2)

        expect do
          expect(result).to eq(1)
        end.to change { add_on_purchase.reload.assigned_users.count }.by(-1)

        expect(add_on_purchase.reload.assigned_users.where(user: user_1).count).to eq(1)
      end

      it 'accepts batch_size and deletes the assignments in batch' do
        expect(GitlabSubscriptions::UserAddOnAssignment).to receive(:pluck_user_ids).twice.and_call_original

        result = add_on_purchase.delete_ineligible_user_assignments_in_batches!(batch_size: 1)

        expect(result).to eq(2)
      end

      context 'when the add_on_purchase has no namespace' do
        before do
          add_on_purchase.update_attribute(:namespace, nil)
        end

        it { is_expected.to eq(0) }
      end
    end

    context 'with no assigned_users records' do
      it { is_expected.to eq(0) }
    end

    context 'when add_on_purchase does not have namespace' do
      before do
        add_on_purchase.update!(namespace: nil)
      end

      it { is_expected.to eq(0) }
    end

    context 'when add_on_purchase does not have group namespace' do
      before do
        add_on_purchase.update!(namespace: create(:user_namespace))
      end

      it { is_expected.to eq(0) }
    end
  end
end
