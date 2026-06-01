# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :conversation
    role    { :user }
    content { 'What documents do I need for a payroll certificate?' }
    status  { :completed }
    metadata { {} }

    trait :assistant do
      role    { :assistant }
      content { 'To obtain a payroll certificate you will need...' }
    end

    trait :pending do
      role    { :assistant }
      status  { :pending }
      content { '' }
    end

    trait :with_sources do
      metadata { { 'sources' => [{ 'title' => 'HR Policy Manual', 'chunk_id' => 1 }] } }
    end
  end
end
