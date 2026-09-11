require "rails_helper"

RSpec.describe Appointments::Book do
  let(:patient) { create(:patient) }
  let(:doctor) { create(:doctor) }
  let!(:availability) { create(:availability, doctor: doctor) }

  before { stub_reminder }

  it "takes a row lock on the availability before deciding the slot is free" do
    stub_invoice_create
    statements = []
    subscriber = ->(_n, _s, _f, _i, payload) { statements << payload[:sql] }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      described_class.call(patient: patient, availability_id: availability.id)
    end

    # The invariant is also backed by a partial unique index, so the absence of this
    # SELECT ... FOR UPDATE would not fail the end-to-end concurrency spec. This is the
    # assertion that would.
    expect(statements).to include(a_string_matching(/SELECT .*"availabilities".*FOR UPDATE/m))
  end

  it "does not lose the booking when billing times out, and queues one retry" do
    stub_request(:post, "http://billing.test/api/v1/invoices/").to_timeout

    result = described_class.call(patient: patient, availability_id: availability.id)

    expect(result).to be_success
    expect(result.appointment).to be_persisted
    expect(result.invoice_deferred).to be(true)

    job = BillingInvoiceWorker.jobs.sole
    expect(job["args"]).to eq([result.appointment.id])
  end

  it "reuses the same idempotency key on the retry, so the invoice is created once" do
    stub_request(:post, "http://billing.test/api/v1/invoices/").to_timeout
    result = described_class.call(patient: patient, availability_id: availability.id)
    expected_key = Digest::SHA256.hexdigest(result.appointment.external_ref)

    WebMock.reset!
    stub_invoice_create(status: 200)
    Sidekiq::Testing.inline! { BillingInvoiceWorker.perform_async(result.appointment.id) }

    expect(
      a_request(:post, "http://billing.test/api/v1/invoices/").with(headers: { "Idempotency-Key" => expected_key })
    ).to have_been_made.once
  end

  it "compensates the booking when billing refuses it outright" do
    stub_invoice_create(status: 422, body: { detail: "account on hold" })

    result = described_class.call(patient: patient, availability_id: availability.id)

    expect(result).to be_failure
    expect(result.errors.sole[:code]).to eq("invoice_rejected")
    expect(Appointment.sole).to be_cancelled
    expect(Appointment.active.count).to be_zero
  end

  it "rolls a committed booking back into a cancellation and a void" do
    stub_invoice_create
    result = described_class.call(patient: patient, availability_id: availability.id)
    appointment = result.appointment

    result.rollback!

    expect(appointment.reload).to be_cancelled
    expect(appointment.cancellation_reason).to eq("booking_rolled_back")
    expect(BillingVoidWorker.jobs.sole["args"]).to eq([appointment.external_ref])
  end

  it "fails cleanly for an account with no patient profile" do
    result = described_class.call(patient: nil, availability_id: availability.id)

    expect(result).to be_failure
    expect(result.errors.sole[:code]).to eq("missing_profile")
  end

  it "enqueues nothing and calls nothing when the slot is gone" do
    stub_invoice_create
    described_class.call(patient: patient, availability_id: availability.id)
    WebMock.reset!
    Sidekiq::Worker.clear_all

    result = described_class.call(patient: create(:patient), availability_id: availability.id)

    expect(result).to be_failure
    expect(AppointmentReminderWorker.jobs).to be_empty
    expect(a_request(:post, "http://billing.test/api/v1/invoices/")).not_to have_been_made
  end
end
