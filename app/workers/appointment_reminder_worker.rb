class AppointmentReminderWorker
  include Sidekiq::Job

  sidekiq_options queue: :notifications, retry: 5

  def perform(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    # Scheduled up to 24 hours ahead, so the world may have moved on: the appointment
    # may be cancelled, already completed, or deleted outright. Reminding a patient
    # about a visit that is not happening is worse than not reminding them.
    return unless appointment&.active?

    NotificationClient.new.send_reminder(appointment)
  rescue InternalServiceClient::UnprocessableError => e
    # A refused reminder is not worth five retries; record it and stop.
    Rails.logger.warn("reminder rejected for appointment #{appointment_id}: #{e.message}")
  end
end
