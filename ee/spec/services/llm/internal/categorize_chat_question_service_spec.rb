# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::Internal::CategorizeChatQuestionService, :saas, feature_category: :duo_chat do
  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:user) { create(:user) }
  let_it_be(:resource) { user }
  let_it_be(:options) { {} }

  subject { described_class.new(user, resource, options) }

  before_all do
    group.add_developer(user)
  end

  include_context 'with ai features enabled for group'

  describe '#execute' do
    context 'when the user is permitted to view the merge request' do
      it_behaves_like 'schedules completion worker' do
        let(:action_name) { :categorize_question }
      end
    end
  end
end
