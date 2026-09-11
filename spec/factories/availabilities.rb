FactoryBot.define do
  factory :availability do
    doctor
    # Sequenced, because (doctor_id, starts_at, ends_at) is unique: two slots built for
    # the same doctor in one example must not land on the same minute.
    sequence(:starts_at) { |n| (7.days.from_now + (n * 45).minutes).change(sec: 0) }
    ends_at { starts_at + 30.minutes }

    trait :past do
      sequence(:starts_at) { |n| (2.days.ago + (n * 45).minutes).change(sec: 0) }
    end

    trait :within_reminder_window do
      sequence(:starts_at) { |n| (3.hours.from_now + (n * 45).minutes).change(sec: 0) }
    end
  end
end
