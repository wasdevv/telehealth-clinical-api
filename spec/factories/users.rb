FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "correct-horse-battery-staple" }
    role { "patient" }

    trait :doctor do
      role { "doctor" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :with_two_factor do
      otp_secret { ROTP::Base32.random }
      otp_enabled { true }
      otp_recovery_code_digests { %w[alpharecovery1 betarecovery22].map { |c| User.recovery_code_digest(c) } }
    end
  end
end
