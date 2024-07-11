# frozen_string_literal: true

RSpec.shared_examples 'schedules completion worker' do
  let(:expected_options) { options.merge(request_id: 'uuid') }

  before do
    allow(SecureRandom).to receive(:uuid).and_return('uuid')
    allow(::Llm::CompletionWorker).to receive(:perform_async)
  end

  it 'worker runs asynchronously with correct params' do
    expect(::Llm::CompletionWorker)
      .to receive(:perform_async)
      .with(user.id, resource.id, resource.class.name, action_name, hash_including(**expected_options))

    expect(subject.execute).to be_success
  end
end
