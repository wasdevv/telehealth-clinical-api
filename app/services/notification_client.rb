# Outbound patient messaging also lives in the billing service; this API sends nothing
# itself, which is why there is no Action Mailer in the stack.
class NotificationClient < InternalServiceClient
  REMINDER_PATH = "/api/v1/notifications/reminder/".freeze

  def send_reminder(appointment)
    post(
      REMINDER_PATH,
      {
        email: appointment.patient.user.email,
        # The contract wants an empty string, not null, when there is no phone on file.
        phone: appointment.patient.contact_phone,
        starts_at: appointment.starts_at.utc.iso8601,
        doctor: appointment.doctor.full_name
      },
      accept: [202]
    )
  end
end
