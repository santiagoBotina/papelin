# frozen_string_literal: true

FactoryBot.define do
  factory :certificate_request do
    association :user
    cert_type         { :payroll }
    status            { :submitted }
    requested_at      { Date.current }
    # R6 (phase-2 plan): `business_days` is not available without
    # `business_time` (or similar). Use plain `5.days.from_now` instead.
    # The HR team will override expected_ready_at explicitly in real seeds.
    expected_ready_at { 5.days.from_now.to_date }
    sequence(:reference_number) { |n| "CR-#{Date.current.year}-#{n.to_s.rjust(5, '0')}" }

    trait :ready do
      status   { :ready }
      ready_at { Date.current }
    end

    trait :overdue do
      status            { :submitted }
      expected_ready_at { 3.days.ago.to_date }
    end
  end
end
