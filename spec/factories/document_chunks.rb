# frozen_string_literal: true

FactoryBot.define do
  factory :document_chunk do
    association :document
    sequence(:chunk_index)
    content   { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    embedding { Array.new(1536) { rand(-1.0..1.0) } }
    metadata  { {} }
  end
end
