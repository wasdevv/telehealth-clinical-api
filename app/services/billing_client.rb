# Client for telehealth-billing-service (Django). The contract — paths, payload keys and
# the Token auth header — is fixed by that service and must not be adjusted here.
class BillingClient < InternalServiceClient
  INVOICES_PATH = "/api/v1/invoices/".freeze
  VOID_PATH = "/api/v1/invoices/void/".freeze
  CURRENCY = "usd".freeze

  # 201 when the invoice is created, 200 when this external_ref already had one. Both
  # mean "the invoice exists", which is the only thing the caller needs to know.
  def create_invoice(appointment)
    post(
      INVOICES_PATH,
      {
        external_ref: appointment.external_ref,
        patient_email: appointment.patient.user.email,
        amount_cents: appointment.doctor.consultation_fee_cents,
        currency: CURRENCY,
        description: description_for(appointment)
      },
      accept: [200, 201],
      headers: { "Idempotency-Key" => self.class.idempotency_key(appointment.external_ref) }
    )
  end

  # 404 means there was nothing to void — the same end state as a successful void, so it
  # is success here too. Anything else is handled by the shared error classification.
  def void_invoice(external_ref)
    post(VOID_PATH, { external_ref: external_ref }, accept: [200, 404])
  end

  # Derived from external_ref, which PostgreSQL generates from the primary key. The same
  # appointment therefore always produces the same key, which is what makes a retry after
  # a timeout safe: the billing service recognises the repeat instead of double-charging.
  def self.idempotency_key(external_ref)
    Digest::SHA256.hexdigest(external_ref.to_s)
  end

  private

  def description_for(appointment)
    # Deliberately generic. The billing service is outside the clinical trust boundary,
    # so the description carries no diagnosis, notes or any other PHI.
    "Telehealth consultation with #{appointment.doctor.full_name} on #{appointment.starts_at.utc.to_date.iso8601}"
  end
end
