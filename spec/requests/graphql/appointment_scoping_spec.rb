require "rails_helper"

RSpec.describe "Appointment visibility", type: :request do
  let(:doctor) { create(:doctor) }
  let(:other_doctor) { create(:doctor) }
  let(:patient) { create(:patient) }
  let(:other_patient) { create(:patient) }
  let(:admin) { create(:user, :admin) }

  let!(:mine) { create(:appointment, patient: patient, availability: create(:availability, doctor: doctor), doctor: doctor) }
  let!(:theirs) do
    create(:appointment, patient: other_patient, availability: create(:availability, doctor: other_doctor), doctor: other_doctor)
  end

  let(:single) { "query($id: ID!) { appointment(id: $id) { id } }" }
  let(:mine_query) { "{ myAppointments { edges { node { id } } } }" }

  def ids_from(body)
    graphql_data(body, "myAppointments", "edges").map { |edge| edge.dig("node", "id") }
  end

  it "shows a patient only their own appointments" do
    expect(ids_from(graphql(mine_query, user: patient.user))).to eq([mine.id.to_s])
  end

  it "shows a doctor only their own appointments" do
    expect(ids_from(graphql(mine_query, user: doctor.user))).to eq([mine.id.to_s])
  end

  it "shows an admin everything" do
    expect(ids_from(graphql(mine_query, user: admin))).to match_array([mine.id.to_s, theirs.id.to_s])
  end

  it "returns null rather than a refusal for someone else's appointment id" do
    body = graphql(single, user: patient.user, variables: { id: theirs.id })

    expect(graphql_data(body, "appointment")).to be_nil
    expect(body["errors"]).to be_nil
  end

  it "filters by status and by start time" do
    create(:appointment, :cancelled, patient: patient, availability: create(:availability, doctor: doctor), doctor: doctor)

    body = graphql(
      "query($s: AppointmentStatusEnum) { myAppointments(status: $s) { edges { node { status } } } }",
      user: patient.user, variables: { s: "CANCELLED" }
    )

    expect(graphql_data(body, "myAppointments", "edges").map { |e| e.dig("node", "status") }).to eq(["CANCELLED"])
  end
end
