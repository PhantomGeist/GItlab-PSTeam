# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::Llm::OpenAi::Completions::SummarizeReview, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:merge_request) do
    create(:merge_request_with_diffs, source_project: project, target_project: project, author: user)
  end

  let_it_be(:merge_request_note) { create(:note, noteable: merge_request, project: project, author: user) }
  let!(:draft_note_by_current_user) { create(:draft_note, merge_request: merge_request, author: user) }
  let!(:draft_note_by_random_user) { create(:draft_note, merge_request: merge_request) }

  let(:template_class) { ::Gitlab::Llm::Templates::SummarizeReview }

  let(:ai_response) do
    {
      choices: [
        {
          message: {
            content: "some ai response text"
          }
        }
      ]
    }.to_json
  end

  let(:prompt_message) do
    build(:ai_message, :summarize_review, user: user, resource: merge_request, request_id: 'uuid')
  end

  subject(:summarize_review) do
    described_class.new(prompt_message, template_class, {}).execute
  end

  describe "#execute" do
    context "with invalid params" do
      context "without merge_request" do
        let(:prompt_message) do
          build(:ai_message, :summarize_review, user: user, resource: nil, request_id: 'uuid')
        end

        it "returns nil" do
          expect(summarize_review).to be_nil
        end
      end
    end

    context "with valid params" do
      it "gets the right template options and calls the openai client" do
        expect_next_instance_of(template_class) do |template|
          expect(template).to receive(:to_prompt).and_return('AI prompt')
        end

        expect_next_instance_of(Gitlab::Llm::OpenAi::Client) do |instance|
          expect(instance)
            .to receive(:chat)
            .with(content: 'AI prompt', moderated: true)
            .and_return(ai_response)
        end

        response_modifier = double
        response_service = double
        params = [user, merge_request, response_modifier,
          { options: { request_id: "uuid", ai_action: :summarize_review } }]

        expect(Gitlab::Llm::OpenAi::ResponseModifiers::Chat)
          .to receive(:new)
          .with(ai_response)
          .and_return(
            response_modifier
          )

        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService)
          .to receive(:new)
          .with(*params)
          .and_return(
            response_service
          )

        expect(response_service).to receive(:execute)

        summarize_review
      end
    end
  end
end
