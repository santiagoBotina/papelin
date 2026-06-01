# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email)       { |n| "user#{n}@example.com" }
    sequence(:employee_id) { |n| "EMP#{n.to_s.rjust(5, '0')}" }
    password               { 'Password1!' }
    first_name             { Faker::Name.first_name }
    last_name              { Faker::Name.last_name }
    role                   { :employee }

    trait :admin do
      role { :admin }
    end
  end
end
