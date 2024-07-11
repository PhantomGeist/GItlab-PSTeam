# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_indexed_namespace, class: '::Zoekt::IndexedNamespace' do
    node { association(:zoekt_node) }
    namespace { association(:namespace) }
  end
end
