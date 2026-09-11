module Types
  class MutationType < BaseObject
    description "Write side of the clinical domain"

    field :book_appointment, mutation: Mutations::BookAppointment
    field :cancel_appointment, mutation: Mutations::CancelAppointment
    field :add_medical_record, mutation: Mutations::AddMedicalRecord
  end
end
