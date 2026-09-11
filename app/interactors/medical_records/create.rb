module MedicalRecords
  # Adds the clinical note for a finished consultation.
  #
  # Expects: context.current_user, context.appointment_id, context.diagnosis, context.notes
  # Provides: context.medical_record
  class Create
    include ApplicationInteractor

    def call
      appointment = Appointment.visible_to(context.current_user).find_by(id: context.appointment_id)
      fail_with(:appointmentId, :not_found, "That appointment does not exist.") if appointment.nil?

      # Only the clinician who held the consultation writes its record. A patient can read
      # their own record but never author one, and this is the rule that says so.
      unless context.current_user.admin? || appointment.doctor_id == context.current_user.doctor&.id
        fail_with(:appointmentId, :not_responsible_doctor, "Only the responsible doctor can add this record.")
      end

      if appointment.cancelled?
        fail_with(:appointmentId, :appointment_cancelled, "A cancelled appointment has no clinical record.")
      end

      create_record(appointment)
    end

    def rollback
      context.medical_record&.destroy
    end

    private

    def create_record(appointment)
      # patient and doctor come from the appointment, never from the client: input that
      # named them could file one patient's diagnosis under another patient's chart.
      context.medical_record = MedicalRecord.create!(
        appointment: appointment,
        doctor_id: appointment.doctor_id,
        patient_id: appointment.patient_id,
        diagnosis: context.diagnosis,
        notes: context.notes
      )

      AuditLog.record!(
        user: context.current_user,
        resource: context.medical_record,
        action: "medical_record.create",
        ip: context.ip
      )
    rescue ActiveRecord::RecordNotUnique
      fail_with(:appointmentId, :record_exists, "This appointment already has a clinical record.")
    rescue ActiveRecord::RecordInvalid => e
      fail_with_record(e.record)
    end
  end
end
