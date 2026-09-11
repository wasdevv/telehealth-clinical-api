module Types
  class AppointmentType < BaseObject
    description "A consultation between a patient and a doctor"

    field :id, ID, null: false
    field :status, AppointmentStatusEnum, null: false
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: false
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: false
    field :cancelled_at, GraphQL::Types::ISO8601DateTime, null: true
    field :cancellation_reason, String, null: true
    field :external_ref, String, null: false, description: "The key the billing service knows this appointment by"
    field :medical_record, MedicalRecordType, null: true

    batch_belongs_to :doctor, type: DoctorType, null: false
    batch_belongs_to :patient, type: PatientType, null: false

    # Scoped lookup rather than `object.medical_record`: an admin-visible appointment and
    # a record the caller may not read are different questions, and this asks the second.
    def medical_record
      MedicalRecord.visible_to(current_user).find_by(appointment_id: object.id)
    end
  end
end
