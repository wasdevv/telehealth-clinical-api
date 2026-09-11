module Mutations
  class CancelAppointment < BaseMutation
    description "Cancel an appointment the caller participates in"

    argument :id, ID, required: true
    argument :reason, String, required: false

    resource_field Types::AppointmentType

    def resolve(id:, reason: nil)
      result = Appointments::Cancel.call(
        current_user: current_user,
        appointment_id: id,
        reason: reason
      )

      payload_for(result, :appointment)
    end
  end
end
