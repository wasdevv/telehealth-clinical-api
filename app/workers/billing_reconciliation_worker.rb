# Re-asserts that every recent active appointment has an invoice.
#
# The billing contract exposes no way to *read* invoices — only create, void and notify —
# so this cannot compare two ledgers and report a difference. What it can do, without
# inventing an endpoint, is re-submit each invoice creation: the Idempotency-Key is
# derived from the appointment's external_ref, so a request for an invoice that already
# exists comes back 200 and changes nothing. That converts "an invoice was lost to a
# timeout and its retry exhausted" from permanent into self-healing within a day.
class BillingReconciliationWorker
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 3

  LOOKBACK = 7.days
  BATCH_SIZE = 200

  def perform
    client = BillingClient.new
    reconciled = 0
    failed = 0

    Appointment.active.where(created_at: LOOKBACK.ago..).find_each(batch_size: BATCH_SIZE) do |appointment|
      client.create_invoice(appointment)
      reconciled += 1
    rescue InternalServiceClient::Error => e
      # One bad appointment must not abort the sweep for every other one.
      failed += 1
      Rails.logger.warn("reconciliation failed for #{appointment.external_ref}: #{e.class}")
    end

    Rails.logger.info("BillingReconciliationWorker reconciled #{reconciled}, failed #{failed}")
    { reconciled: reconciled, failed: failed }
  end
end
