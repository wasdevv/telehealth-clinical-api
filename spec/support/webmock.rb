require "webmock/rspec"

# Only the transport boundary is stubbed. Everything between a GraphQL mutation and
# Net::HTTP is the real code path, so a spec that passes has exercised it.
WebMock.disable_net_connect!(allow_localhost: true)

BILLING_URL = "http://billing.test".freeze

RSpec.configure do |config|
  config.before do
    ENV["DJANGO_BILLING_URL"] = BILLING_URL
    ENV["INTERNAL_SERVICE_TOKEN"] = "test-internal-token"
  end
end

module BillingStubs
  def stub_invoice_create(status: 201, body: { id: 1 })
    stub_request(:post, "#{BILLING_URL}/api/v1/invoices/")
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_invoice_void(status: 200)
    stub_request(:post, "#{BILLING_URL}/api/v1/invoices/void/")
      .to_return(status: status, body: "{}", headers: { "Content-Type" => "application/json" })
  end

  def stub_reminder(status: 202)
    stub_request(:post, "#{BILLING_URL}/api/v1/notifications/reminder/")
      .to_return(status: status, body: "{}", headers: { "Content-Type" => "application/json" })
  end
end

RSpec.configure { |config| config.include BillingStubs }
