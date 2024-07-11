# frozen_string_literal: true

FactoryBot.modify do
  factory :work_item do
    trait :requirement do
      association :work_item_type, :default, :requirement
    end

    trait :test_case do
      association :work_item_type, :default, :test_case
    end

    trait :objective do
      association :work_item_type, :default, :objective
    end

    trait :key_result do
      association :work_item_type, :default, :key_result
    end

    trait :epic do
      association :work_item_type, :default, :epic
    end

    trait :satisfied_status do
      association :work_item_type, :default, :requirement

      after(:create) do |work_item|
        create(:test_report, requirement_issue: work_item, state: :passed)
      end
    end

    trait :failed_status do
      association :work_item_type, :default, :requirement

      after(:create) do |work_item|
        create(:test_report, requirement_issue: work_item, state: :failed)
      end
    end

    after(:build) do |work_item|
      next unless work_item.work_item_type.requirement?

      work_item.build_requirement(project: work_item.project)
    end
  end
end
