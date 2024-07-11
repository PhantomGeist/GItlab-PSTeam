# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::RelatedEpicLinks::CreateService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:user) { create :user }
    let_it_be(:group) { create :group }
    let_it_be(:issuable) { create :epic, group: group }
    let_it_be(:issuable2) { create :epic, group: group }
    let_it_be(:restricted_issuable) { create(:epic, group: create(:group, :private)) }
    let_it_be(:another_group) { create :group }
    let_it_be(:issuable3) { create :epic, group: another_group }
    let_it_be(:issuable_a) { create :epic, group: group }
    let_it_be(:issuable_b) { create :epic, group: group }
    let_it_be(:issuable_link) { create :related_epic_link, source: issuable, target: issuable_b, link_type: IssuableLink::TYPE_RELATES_TO }

    let(:issuable_parent) { issuable.group }
    let(:issuable_type) { :epic }
    let(:issuable_link_class) { Epic::RelatedEpicLink }
    let(:params) { {} }

    before do
      stub_licensed_features(epics: true, related_epics: true)
      group.add_guest(user)
      another_group.add_guest(user)
    end

    it_behaves_like 'issuable link creation'
    it_behaves_like 'issuable link creation with blocking link_type' do
      let(:params) do
        { issuable_references: [issuable2.to_reference, issuable3.to_reference(issuable3.group, full: true)] }
      end
    end

    context 'with permission checks' do
      let_it_be(:other_user) { create(:user) }

      let(:error_msg) { "Couldn't link epics. You must have at least the Guest role in the epic's group." }
      let(:params) { { issuable_references: [issuable3.to_reference(full: true)] } }

      subject { described_class.new(issuable, current_user, params).execute }

      shared_examples 'creates link' do
        it 'creates relationship', :aggregate_failures do
          expect { subject }.to change(issuable_link_class, :count).by(1)

          expect(issuable_link_class.find_by!(target: issuable3))
            .to have_attributes(source: issuable, link_type: 'relates_to')
        end
      end

      shared_examples 'fails to create link' do
        it 'does not create relationship', :aggregate_failures do
          expect { subject }.not_to change { issuable_link_class.count }
          is_expected.to eq(message: error_msg, status: :error, http_status: 403)
        end
      end

      context 'when user is not a guest in source group' do
        let_it_be(:current_user) { create(:user).tap { |user| another_group.add_guest(user) } }

        it_behaves_like 'fails to create link'
      end

      context 'when user is not a guest in target group' do
        let_it_be(:current_user) { create(:user).tap { |user| group.add_guest(user) } }

        it_behaves_like 'creates link'
      end

      context 'when related_epics feature is not available' do
        let(:current_user) { user }

        context 'for source group' do
          before do
            stub_licensed_features(epics: true, related_epics: false)
            allow(another_group).to receive(:licensed_feature_available?).with(anything).and_call_original
            allow(another_group).to receive(:licensed_feature_available?).with(:related_epics).and_return(true)
          end

          it_behaves_like 'fails to create link'
        end

        context 'for target group' do
          before do
            stub_licensed_features(epics: true, related_epics: false)
            allow(group).to receive(:licensed_feature_available?).with(anything).and_call_original
            allow(group).to receive(:licensed_feature_available?).with(:related_epics).and_return(true)
          end

          it_behaves_like 'creates link'
        end
      end
    end

    context 'event tracking' do
      shared_examples 'a recorded event' do
        it 'records event for each link created' do
          params = {
            link_type: link_type,
            issuable_references: [issuable_a, issuable3].map { |epic| epic.to_reference(issuable.group, full: true) }
          }

          expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(tracking_method_name)
            .with(author: user, namespace: group).twice

          described_class.new(issuable, user, params).execute
        end
      end

      context 'for relates_to link type' do
        let(:link_type) { IssuableLink::TYPE_RELATES_TO }
        let(:tracking_method_name) { :track_linked_epic_with_type_relates_to_added }

        it_behaves_like 'a recorded event'
      end

      context 'for blocks link_type' do
        let(:link_type) { IssuableLink::TYPE_BLOCKS }
        let(:tracking_method_name) { :track_linked_epic_with_type_blocks_added }

        it_behaves_like 'a recorded event'
      end

      context 'for is_blocked_by link_type' do
        let(:link_type) { IssuableLink::TYPE_IS_BLOCKED_BY }
        let(:tracking_method_name) { :track_linked_epic_with_type_is_blocked_by_added }

        it_behaves_like 'a recorded event'
      end
    end
  end
end
