# frozen_string_literal: true

RSpec.shared_examples 'assigns one or more reviewers to the merge request' do |example|
  before do
    target.reviewers = [reviewer]
  end

  it 'adds multiple reviewers from the list' do
    _, update_params, message = service.execute(note)

    expected_format = example[:multiline] ? /Assigned @\w+ as reviewer. Assigned @\w+ as reviewer./ : /Assigned @\w+ and @\w+ as reviewers./

    expect(message).to match(expected_format)
    expect(message).to include("@#{reviewer.username}")
    expect(message).to include("@#{user.username}")

    expect(update_params[:reviewer_ids]).to match_array([user.id, reviewer.id])
    expect { service.apply_updates(update_params, note) }.not_to raise_error
  end
end
