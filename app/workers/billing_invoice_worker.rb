# The retry path for an invoice the booking request could not create in time. Safe to run
# any number of times: the Idempotency-Key is derived from the appointment's external_ref,
# so the billing service answers 200 for one it already has.
class BillingInvoiceWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 10

  def perform(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    return unless appointment&.active?

    BillingClient.new.create_invoice(appointment)
  end
end
