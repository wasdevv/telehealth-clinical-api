module Types
  class AvailabilityType < BaseObject
    description "A bookable slot in a doctor's calendar"

    field :id, ID, null: false
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: false
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: false

    batch_belongs_to :doctor, type: DoctorType, null: false
  end
end
