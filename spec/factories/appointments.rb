FactoryBot.define do
  factory :appointment do
    patient
    availability
    doctor { availability.doctor }
    starts_at { availability.starts_at }
    ends_at { availability.ends_at }
    status { "scheduled" }

    trait :cancelled do
      status { "cancelled" }
      cancelled_at { Time.current }
    end

    trait :completed do
      status { "completed" }
    end
  end
end
