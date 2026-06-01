# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    association :uploaded_by, factory: :user, strategy: :create
    title       { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    doc_type    { :policy }
    status      { :ready }

    trait :pending do
      status { :pending }
    end
    trait :processing do
      status { :processing }
    end
    trait :ready      do
      status { :ready }
    end
    trait :failed do
      status { :failed }
      processing_error { 'PDF parsing failed: unexpected EOF' }
    end
  end
end
