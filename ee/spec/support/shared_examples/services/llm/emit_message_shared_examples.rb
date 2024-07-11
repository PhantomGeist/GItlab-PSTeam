# frozen_string_literal: true

RSpec.shared_examples 'service emitting message for user prompt' do
  it 'triggers graphql subscription message' do
    allow(::Llm::CompletionWorker).to receive(:perform_async)

    expect(GraphqlTriggers).to receive(:ai_completion_response)
      .with(an_object_having_attributes(
        user: user,
        resource: resource,
        ai_action: :chat
      ))

    subject.execute
  end
end
