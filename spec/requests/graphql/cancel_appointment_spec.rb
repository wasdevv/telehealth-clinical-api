require "rails_helper"

RSpec.describe "cancelAppointment", type: :request do
  let(:doctor) { create(:doctor) }
  let(:patient) { create(:patient) }
  let!(:appointment) do
    create(:appointment, patient: patient, availability: create(:availability, doctor: doctor), doctor: doctor)
  end

  let(:mutation) do
    <<~GQL
      mutation($id: ID!, $reason: String) {
        cancelAppointment(id: $id, reason: $reason) {
          resource { id status cancellationReason }
          errors { field code message }
        }
      }
    GQL
  end

  it "cancels the appointment and voids the invoice" do
    stub_invoice_void

    body = graphql(mutation, user: patient.user, variables: { id: appointment.id, reason: "Feeling better" })

    expect(graphql_data(body, "cancelAppointment", "resource", "status")).to eq("CANCELLED")
    expect(appointment.reload).to be_cancelled
    expect(a_request(:post, "http://billing.test/api/v1/invoices/void/")).to have_been_made.once
  end

  it "treats a 404 from void as success, because the end state is the same" do
    stub_invoice_void(status: 404)

    body = graphql(mutation, user: patient.user, variables: { id: appointment.id, reason: nil })

    expect(graphql_data(body, "cancelAppointment", "errors")).to be_empty
    expect(BillingVoidWorker.jobs).to be_empty
  end

  it "still cancels when billing times out, and queues the void for later" do
    stub_request(:post, "http://billing.test/api/v1/invoices/void/").to_timeout

    body = graphql(mutation, user: patient.user, variables: { id: appointment.id, reason: nil })

    expect(graphql_data(body, "cancelAppointment", "errors")).to be_empty
    expect(appointment.reload).to be_cancelled
    expect(BillingVoidWorker.jobs.sole["args"]).to eq(["appointment:#{appointment.id}"])
  end

  it "frees the slot for someone else" do
    stub_invoice_void
    stub_invoice_create
    stub_reminder
    graphql(mutation, user: patient.user, variables: { id: appointment.id, reason: nil })

    result = Appointments::Book.call(patient: create(:patient), availability_id: appointment.availability_id)

    expect(result).to be_success
  end

  it "refuses to cancel an appointment that is already cancelled" do
    stub_invoice_void
    graphql(mutation, user: patient.user, variables: { id: appointment.id, reason: nil })

    body = graphql(mutation, user: patient.user, variables: { id: appointment.id, reason: nil })

    expect(graphql_data(body, "cancelAppointment", "errors").sole["code"]).to eq("not_cancellable")
  end

  it "refuses a stranger" do
    body = graphql(mutation, user: create(:patient).user, variables: { id: appointment.id, reason: nil })

    expect(graphql_data(body, "cancelAppointment", "errors").sole["code"]).to eq("not_found")
    expect(appointment.reload).to be_scheduled
  end
end
