# frozen_string_literal: true

FactoryBot.define do
  factory :conversation do
    association :user
    title  { Faker::Lorem.sentence(word_count: 5) }
    status { :active }
  end
end
