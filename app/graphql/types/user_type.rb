module Types
  class UserType < BaseObject
    description "An account"

    field :id, ID, null: false
    field :email, String, null: false
    field :role, UserRoleEnum, null: false
    field :two_factor_enabled, Boolean, null: false, method: :otp_enabled
    field :patient, PatientType, null: true
    field :doctor, DoctorType, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
