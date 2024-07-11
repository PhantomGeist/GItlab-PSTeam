# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :ai_message, class: 'Gitlab::Llm::AiMessage' do
    id { nil }
    association :user
    resource { nil }
    role { 'user' }
    request_id { SecureRandom.uuid }
    content { 'user message' }
    timestamp { Time.current }
    extras { nil }
    errors { nil }
    ai_action { :explain_code }
    client_subscription_id { nil }
    type { nil }
    chunk_id { nil }

    initialize_with do
      new(
        id: id,
        role: role,
        user: user,
        request_id: request_id,
        content: content,
        timestamp: timestamp,
        extras: extras,
        errors: errors,
        ai_action: ai_action,
        client_subscription_id: client_subscription_id,
        resource: resource,
        type: type,
        chunk_id: chunk_id
      )
    end

    trait :explain_code do
      ai_action { :explain_code }
    end

    trait :explain_vulnerability do
      ai_action { :explain_vulnerability }
    end

    trait :fill_in_merge_request_template do
      ai_action { :fill_in_merge_request_template }
    end

    trait :generate_commit_message do
      ai_action { :generate_commit_message }
    end

    trait :generate_test_file do
      ai_action { :generate_test_file }
    end

    trait :summarize_merge_request do
      ai_action { :summarize_merge_request }
    end

    trait :summarize_review do
      ai_action { :summarize_review }
    end

    trait :summarize_submitted_review do
      ai_action { :summarize_submitted_review }
    end

    trait :analyze_ci_job_failure do
      ai_action { :analyze_ci_job_failure }
    end

    trait :generate_description do
      ai_action { :generate_description }
    end

    trait :tanuki_bot do
      ai_action { :tanuki_bot }
    end

    trait :summarize_comments do
      ai_action { :summarize_comments }
    end

    trait :categorize_question do
      ai_action { :categorize_question }
    end

    skip_create

    factory :ai_chat_message, class: 'Gitlab::Llm::ChatMessage' do
      ai_action { :chat }

      to_create(&:save!)
    end
  end
end
