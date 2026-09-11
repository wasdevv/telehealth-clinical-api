module Types
  class PatientType < BaseObject
    description "A patient profile"

    field :id, ID, null: false
    field :full_name, String, null: false
    field :phone, String, null: true
    field :date_of_birth, GraphQL::Types::ISO8601Date, null: true

    batch_belongs_to :user, type: UserType, null: false
  end
end
