module Mutations
  class BookAppointment < BaseMutation
    description "Reserve a doctor's free slot for the calling patient"

    argument :availability_id, ID, required: true

    resource_field Types::AppointmentType

    def resolve(availability_id:)
      # The patient comes from the token, never from the input. A patient id in the
      # arguments would let anyone book on anyone else's behalf.
      result = Appointments::Book.call(
        patient: current_user.patient,
        availability_id: availability_id
      )

      payload_for(result, :appointment)
    end
  end
end
