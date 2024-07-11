# frozen_string_literal: true

RSpec.shared_examples 'issuable link creation with blocking link_type' do
  let(:async_notes) { false }

  subject { described_class.new(issuable, user, params).execute }

  context 'when is_blocked_by relation is used' do
    before do
      params[:link_type] = 'is_blocked_by'
    end

    it 'creates `blocks` relation with swapped source and target' do
      expect { subject }.to change(issuable_link_class, :count).by(2)

      expect(issuable_link_class.find_by!(source: issuable2)).to have_attributes(target: issuable, link_type: 'blocks')
      expect(issuable_link_class.find_by!(source: issuable3)).to have_attributes(target: issuable, link_type: 'blocks')
    end

    it 'creates block and blocked_by notes with swapped issuables' do
      if async_notes
        expect(Issuable::RelatedLinksCreateWorker).to receive(:perform_async) do |args|
          expect(args).to eq(
            {
              issuable_class: issuable.class.name,
              issuable_id: issuable.id,
              link_ids: issuable_link_class.where(target: issuable).last(2).pluck(:id),
              link_type: 'is_blocked_by',
              user_id: user.id
            }
          )
        end
      else
        # First block and blocked_by notes
        expect(SystemNoteService).to receive(:block_issuable)
                                       .with(issuable2, issuable, user)
        expect(SystemNoteService).to receive(:blocked_by_issuable)
                                       .with(issuable, issuable2, user)

        # Second block and blocked_by notes
        expect(SystemNoteService).to receive(:block_issuable)
                                       .with(issuable3, issuable, user)
        expect(SystemNoteService).to receive(:blocked_by_issuable)
                                       .with(issuable, issuable3, user)
      end

      subject
    end
  end

  context 'when blocks relation is used' do
    before do
      params[:link_type] = 'blocks'
    end

    it 'creates `blocks` relation' do
      expect { subject }.to change(issuable_link_class, :count).by(2)

      expect(issuable_link_class.find_by!(target: issuable2)).to have_attributes(source: issuable, link_type: 'blocks')
      expect(issuable_link_class.find_by!(target: issuable3)).to have_attributes(source: issuable, link_type: 'blocks')
    end

    it 'creates block and blocked_by notes' do
      if async_notes
        expect(Issuable::RelatedLinksCreateWorker).to receive(:perform_async) do |args|
          expect(args).to eq(
            {
              issuable_class: issuable.class.name,
              issuable_id: issuable.id,
              link_ids: issuable_link_class.where(source: issuable).last(2).pluck(:id),
              link_type: 'blocks',
              user_id: user.id
            }
          )
        end
      else
        # First block and blocked_by notes
        expect(SystemNoteService).to receive(:block_issuable)
                                       .with(issuable, issuable2, user)
        expect(SystemNoteService).to receive(:blocked_by_issuable)
                                       .with(issuable2, issuable, user)

        # Second block and blocked_by notes
        expect(SystemNoteService).to receive(:block_issuable)
                                       .with(issuable, issuable3, user)
        expect(SystemNoteService).to receive(:blocked_by_issuable)
                                       .with(issuable3, issuable, user)
      end

      subject
    end
  end
end
