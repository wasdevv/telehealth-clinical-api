FactoryBot.define do
  factory :patient do
    association :user, factory: :user
    sequence(:full_name) { |n| "Patient #{n}" }
    phone { "+15550000000" }
    date_of_birth { 30.years.ago.to_date }
  end
end
