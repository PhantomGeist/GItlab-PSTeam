# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LabelLink, feature_category: :global_search do
  describe 'callback ' do
    describe 'after_destroy' do
      let_it_be_with_reload(:label) { create(:label) }
      let_it_be(:label2) { create(:label) }

      context 'for issues' do
        let_it_be(:issue) { create(:labeled_issue, labels: [label]) }
        let_it_be(:issue2) { create(:labeled_issue, labels: [label]) }
        let_it_be(:issue3) { create(:labeled_issue, labels: [label2]) }

        it 'synchronizes elasticsearch only for issues which have deleted label attached' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(issue).once
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(issue2).once
          label.destroy!
        end
      end

      context 'for epics' do
        let_it_be(:epic) { create(:labeled_epic, labels: [label]) }
        let_it_be(:epic2) { create(:labeled_issue, labels: [label]) }
        let_it_be(:epic3) { create(:labeled_issue, labels: [label2]) }

        it 'synchronizes elasticsearch only for epics which have deleted label attached' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(epic2).once
          label.destroy!
        end
      end
    end
  end
end
