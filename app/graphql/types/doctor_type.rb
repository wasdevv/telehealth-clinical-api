module Types
  class DoctorType < BaseObject
    description "A clinician"

    field :id, ID, null: false
    field :full_name, String, null: false
    field :specialty, String, null: false
    field :consultation_fee_cents, Integer, null: false
    field :availabilities, [AvailabilityType], null: false do
      description "Slots that are still free, soonest first"
    end

    batch_belongs_to :user, type: UserType, null: false

    def availabilities
      object.availabilities.upcoming.unbooked.order(:starts_at).limit(50)
    end
  end
end
