# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_node, class: '::Search::Zoekt::Node' do
    index_base_url { "http://#{SecureRandom.hex(4)}.example.com" }
    search_base_url { "http://#{SecureRandom.hex(4)}.example.com" }
    uuid { SecureRandom.uuid }
    last_seen_at { Time.zone.now }
    used_bytes { 10 }
    total_bytes { 100 }

    sequence(:metadata) do |n|
      { name: "zoekt-#{n}" }
    end
  end
end
