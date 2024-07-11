# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat', :js, :saas, :clean_gitlab_redis_cache, feature_category: :duo_chat do
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:user) { create(:user) }

  before_all do
    group.add_developer(user)
  end

  before do
    stub_licensed_features(ai_tanuki_bot: true)
    stub_application_setting(anthropic_api_key: 'somekey')
  end

  context 'when group has no AI features enabled' do
    before do
      sign_in(user)
      visit root_path
    end

    it 'does not show the button to open chat' do
      expect(page).not_to have_button('GitLab Duo Chat')
    end
  end

  context 'when group has AI features enabled', :sidekiq_inline do
    include_context 'with ai features enabled for group'

    let(:question) { 'Who are you?' }
    let(:answer) { 'I am GitLab Duo Chat' }

    let(:chat_response) do
      <<-DOC
      event: completion\r
      data: {"completion":"Final Answer: ", "stop_reason": null, "model": "claude-2.0" }\r
      \r
      event: completion\r
      data: {"completion":"#{answer}", "stop_reason": null, "model": "claude-2.0" }\r
      \r
      DOC
    end

    before do
      stub_request(:post, "https://api.anthropic.com/v1/complete")
        .to_return(
          status: 200, body: { completion: "question_category" }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:post, "https://api.anthropic.com/v1/complete")
        .with(body: hash_including({ "stream" => true }))
        .to_return(status: 200, body: chat_response)

      sign_in(user)

      visit root_path
    end

    it 'returns response after asking a question' do
      open_chat
      chat_request(question)

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(answer)
      end
    end

    it 'stores the chat history' do
      open_chat
      chat_request(question)

      page.refresh
      open_chat

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(answer)
      end
    end

    it 'syncs the chat on a second tab' do
      second_window = page.open_new_window

      within_window second_window do
        visit root_path
        open_chat
      end

      open_chat
      chat_request(question)

      within_window second_window do
        within_testid('chat-component') do
          expect(page).to have_content(question)
          expect(page).to have_content(answer)
        end
      end
    end
  end

  def open_chat
    click_button "GitLab Duo Chat"
  end

  def chat_request(question)
    fill_in 'GitLab Duo Chat', with: question
    send_keys :enter
    wait_for_requests
  end
end
