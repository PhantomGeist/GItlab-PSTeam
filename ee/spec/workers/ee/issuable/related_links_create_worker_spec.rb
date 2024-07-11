# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuable::RelatedLinksCreateWorker, feature_category: :portfolio_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:issuable) { create(:work_item, :task, project: project) }
  let_it_be(:item1) { create(:work_item, :task, project: project) }
  let_it_be(:item2) { create(:work_item, :task, project: project) }
  let_it_be(:user) { create(:user) }

  let(:params) do
    {
      issuable_class: issuable.class.name,
      issuable_id: issuable.id,
      user_id: user.id
    }
  end

  before_all do
    project.add_reporter(user)
  end

  subject { described_class.new.perform(params) }

  describe '#perform' do
    context 'when items are marked as blocked' do
      let(:blocked1) { item1 }
      let(:blocked2) { item2 }

      before do
        blocked_link1 = create(:work_item_link, source: issuable, target: blocked1, link_type: 'blocks')
        blocked_link2 = create(:work_item_link, source: issuable, target: blocked2, link_type: 'blocks')

        params.merge!(link_ids: [blocked_link1.id, blocked_link2.id], link_type: 'blocks')
      end

      it 'calls correct methods on SystemNoteService' do
        expect(SystemNoteService).to receive(:block_issuable).with(issuable, [blocked1, blocked2], user)
        expect(SystemNoteService).to receive(:blocked_by_issuable).with(blocked1, issuable, user)
        expect(SystemNoteService).to receive(:blocked_by_issuable).with(blocked2, issuable, user)

        subject
      end

      it 'creates correct notes' do
        subject

        expect(issuable.notes.last.note)
          .to eq("marked this task as blocking #{blocked1.to_reference} and #{blocked2.to_reference}")
        expect(blocked1.notes.last.note).to eq("marked this task as blocked by #{issuable.to_reference}")
        expect(blocked2.notes.last.note).to eq("marked this task as blocked by #{issuable.to_reference}")
      end
    end

    context 'when items are marked as blocking' do
      let(:blocking1) { item1 }
      let(:blocking2) { item2 }

      before do
        blocking_link1 = create(:work_item_link, source: blocking1, target: issuable, link_type: 'blocks')
        blocking_link2 = create(:work_item_link, source: blocking2, target: issuable, link_type: 'blocks')

        params.merge!(link_ids: [blocking_link1.id, blocking_link2.id], link_type: 'is_blocked_by')
      end

      it 'calls correct methods on SystemNoteService' do
        expect(SystemNoteService).to receive(:blocked_by_issuable).with(issuable, [blocking1, blocking2], user)
        expect(SystemNoteService).to receive(:block_issuable).with(blocking1, issuable, user)
        expect(SystemNoteService).to receive(:block_issuable).with(blocking2, issuable, user)

        subject
      end

      it 'creates correct notes' do
        subject

        expect(issuable.notes.last.note)
          .to eq("marked this task as blocked by #{blocking1.to_reference} and #{blocking2.to_reference}")
        expect(blocking1.notes.last.note).to eq("marked this task as blocking #{issuable.to_reference}")
        expect(blocking2.notes.last.note).to eq("marked this task as blocking #{issuable.to_reference}")
      end
    end
  end
end
