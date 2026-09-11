module Mutations
  class AddMedicalRecord < BaseMutation
    description "File the clinical record for a consultation"

    argument :appointment_id, ID, required: true
    argument :diagnosis, String, required: true
    argument :notes, String, required: false

    resource_field Types::MedicalRecordType

    def resolve(appointment_id:, diagnosis:, notes: nil)
      result = MedicalRecords::Create.call(
        current_user: current_user,
        appointment_id: appointment_id,
        diagnosis: diagnosis,
        notes: notes,
        ip: context[:ip]
      )

      payload_for(result, :medical_record)
    end
  end
end
