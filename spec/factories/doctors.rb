FactoryBot.define do
  factory :doctor do
    association :user, factory: %i[user doctor]
    sequence(:full_name) { |n| "Dr. Doctor #{n}" }
    specialty { "cardiology" }
    consultation_fee_cents { 15_000 }
  end
end
