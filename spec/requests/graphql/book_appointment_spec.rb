require "rails_helper"

RSpec.describe "bookAppointment", type: :request do
  let(:patient) { create(:patient) }
  let(:doctor) { create(:doctor) }
  let!(:availability) { create(:availability, doctor: doctor) }

  let(:mutation) do
    <<~GQL
      mutation($availabilityId: ID!) {
        bookAppointment(availabilityId: $availabilityId) {
          resource { id status startsAt externalRef doctor { fullName } patient { fullName } }
          errors { field code message }
        }
      }
    GQL
  end

  before do
    stub_invoice_create
    stub_reminder
  end

  it "books a free slot and schedules the reminder 24 hours ahead" do
    body = graphql(mutation, user: patient.user, variables: { availabilityId: availability.id })
    payload = graphql_data(body, "bookAppointment")

    expect(payload["errors"]).to be_empty
    expect(payload["resource"]["status"]).to eq("SCHEDULED")
    expect(payload["resource"]["doctor"]["fullName"]).to eq(doctor.full_name)

    appointment = Appointment.sole
    expect(appointment.starts_at).to eq(availability.starts_at)
    expect(payload["resource"]["externalRef"]).to eq("appointment:#{appointment.id}")

    job = AppointmentReminderWorker.jobs.sole
    expect(job["args"]).to eq([appointment.id])
    expect(Time.at(job["at"]).utc).to be_within(1.second).of(appointment.starts_at - 24.hours)
  end

  it "sends the billing service the exact contract, with the derived idempotency key" do
    graphql(mutation, user: patient.user, variables: { availabilityId: availability.id })
    appointment = Appointment.sole

    expect(
      a_request(:post, "http://billing.test/api/v1/invoices/").with(
        headers: {
          "Authorization" => "Token test-internal-token",
          "Idempotency-Key" => Digest::SHA256.hexdigest("appointment:#{appointment.id}")
        }
      ) do |req|
        JSON.parse(req.body).slice("external_ref", "patient_email", "amount_cents", "currency") == {
          "external_ref" => "appointment:#{appointment.id}",
          "patient_email" => patient.user.email,
          "amount_cents" => 15_000,
          "currency" => "usd"
        }
      end
    ).to have_been_made.once
  end

  it "rejects a second booking of the same slot" do
    graphql(mutation, user: patient.user, variables: { availabilityId: availability.id })

    other = create(:patient)
    body = graphql(mutation, user: other.user, variables: { availabilityId: availability.id })
    payload = graphql_data(body, "bookAppointment")

    expect(payload["resource"]).to be_nil
    expect(payload["errors"].sole["code"]).to eq("slot_taken")
    expect(Appointment.active.count).to eq(1)
  end

  it "rejects a slot whose time has already passed" do
    past = create(:availability, :past, doctor: doctor)

    body = graphql(mutation, user: patient.user, variables: { availabilityId: past.id })

    expect(graphql_data(body, "bookAppointment", "errors").sole["code"]).to eq("in_the_past")
  end

  it "sends the reminder immediately when the slot is less than 24 hours away" do
    soon = create(:availability, :within_reminder_window, doctor: doctor)

    graphql(mutation, user: patient.user, variables: { availabilityId: soon.id })

    expect(AppointmentReminderWorker.jobs.sole["at"]).to be_nil
  end

  it "refuses an unauthenticated caller" do
    post "/graphql",
         params: { query: mutation, variables: { availabilityId: availability.id } }.to_json,
         headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(Appointment.count).to be_zero
  end
end
