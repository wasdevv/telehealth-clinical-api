require "rails_helper"

RSpec.describe BillingClient do
  let(:appointment) do
    doctor = create(:doctor, consultation_fee_cents: 15_000)
    create(:appointment, availability: create(:availability, doctor: doctor), doctor: doctor)
  end

  it "posts the contract payload with the Token header and the derived idempotency key" do
    stub_invoice_create

    described_class.new.create_invoice(appointment)

    expect(
      a_request(:post, "http://billing.test/api/v1/invoices/").with(
        headers: {
          "Authorization" => "Token test-internal-token",
          "Content-Type" => "application/json",
          "Idempotency-Key" => Digest::SHA256.hexdigest(appointment.external_ref)
        }
      ) do |req|
        body = JSON.parse(req.body)
        body["external_ref"] == appointment.external_ref &&
          body["patient_email"] == appointment.patient.user.email &&
          body["amount_cents"] == 15_000 &&
          body["currency"] == "usd" &&
          body["description"].is_a?(String)
      end
    ).to have_been_made.once
  end

  it "keeps PHI out of the invoice description" do
    stub_invoice_create
    described_class.new.create_invoice(appointment)

    expect(
      a_request(:post, "http://billing.test/api/v1/invoices/")
        .with { |req| !JSON.parse(req.body)["description"].match?(/diagnos|note/i) }
    ).to have_been_made
  end

  it "accepts 200 as well as 201" do
    stub_invoice_create(status: 200)

    expect { described_class.new.create_invoice(appointment) }.not_to raise_error
  end

  it "classifies a timeout as retryable" do
    stub_request(:post, "http://billing.test/api/v1/invoices/").to_timeout

    expect { described_class.new.create_invoice(appointment) }
      .to raise_error(InternalServiceClient::RetryableError)
  end

  it "classifies a 503 as retryable and a 422 as not" do
    stub_invoice_create(status: 503)
    expect { described_class.new.create_invoice(appointment) }.to raise_error(InternalServiceClient::RetryableError)

    WebMock.reset!
    stub_invoice_create(status: 422)
    expect { described_class.new.create_invoice(appointment) }.to raise_error(InternalServiceClient::UnprocessableError)
  end

  it "treats a void 404 as success" do
    stub_invoice_void(status: 404)

    expect { described_class.new.void_invoice(appointment.external_ref) }.not_to raise_error
  end

  it "refuses to start without the service URL" do
    ENV["DJANGO_BILLING_URL"] = ""

    expect { described_class.new }.to raise_error(InternalServiceClient::ConfigurationError)
  end

  it "uses short timeouts" do
    expect(InternalServiceClient::OPEN_TIMEOUT).to eq(2)
    expect(InternalServiceClient::READ_TIMEOUT).to eq(5)
  end
end
