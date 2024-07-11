# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::EpicLinks::DestroyService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:child_epic_group) { create(:group, :private) }
    let_it_be(:parent_epic_group) { create(:group, :private) }
    let_it_be_with_reload(:parent_epic) { create(:epic, group: parent_epic_group) }
    let_it_be_with_reload(:child_epic) { create(:epic, parent: parent_epic, group: child_epic_group) }

    shared_examples 'system notes created' do
      it 'creates system notes' do
        expect { subject }.to change { Note.system.count }.from(0).to(2)
      end
    end

    shared_examples 'returns success' do
      it 'removes epic relationship' do
        expect { subject }.to change { parent_epic.children.count }.by(-1)

        expect(parent_epic.reload.children).not_to include(child_epic)
      end

      it 'returns success status' do
        expect(subject).to eq(message: 'Relation was removed', status: :success)
      end
    end

    shared_examples 'returns not found error' do
      it 'returns an error' do
        expect(subject).to eq(message: 'No Epic found for given params', status: :error, http_status: 404)
      end

      it 'no relationship is created' do
        expect { subject }.not_to change { parent_epic.children.count }
      end

      it 'does not create system notes' do
        expect { subject }.not_to change { Note.system.count }
      end
    end

    def remove_epic_relation(child_epic)
      described_class.new(child_epic, user).execute
    end

    context 'when epics feature is disabled' do
      before do
        stub_licensed_features(epics: false)
      end

      subject { remove_epic_relation(child_epic) }

      include_examples 'returns not found error'
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when the user has no access to parent epic' do
        subject { remove_epic_relation(child_epic) }

        before_all do
          child_epic_group.add_guest(user)
        end

        include_examples 'returns not found error'

        context 'when `epic_relations_for_non_members` feature flag is disabled' do
          let_it_be(:child_epic_group) { create(:group, :public) }

          before do
            stub_feature_flags(epic_relations_for_non_members: false)
          end

          include_examples 'returns not found error'
        end
      end

      context 'when the user has no access to child epic' do
        subject { remove_epic_relation(child_epic) }

        before_all do
          parent_epic_group.add_guest(user)
        end

        include_examples 'returns not found error'
      end

      context 'when user has permissions to remove epic relation' do
        before_all do
          child_epic_group.add_guest(user)
          parent_epic_group.add_guest(user)
        end

        context 'when the child epic is nil' do
          subject { remove_epic_relation(nil) }

          include_examples 'returns not found error'
        end

        context 'when a correct reference is given' do
          subject { remove_epic_relation(child_epic) }

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when epic has no parent' do
          subject { remove_epic_relation(parent_epic) }

          include_examples 'returns not found error'
        end
      end
    end
  end
end
