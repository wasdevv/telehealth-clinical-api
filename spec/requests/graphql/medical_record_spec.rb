require "rails_helper"

RSpec.describe "Medical records", type: :request do
  let(:doctor) { create(:doctor) }
  let(:patient) { create(:patient) }
  let(:appointment) do
    create(:appointment, patient: patient, availability: create(:availability, doctor: doctor), doctor: doctor)
  end
  let!(:record) { create(:medical_record, appointment: appointment, doctor: doctor, patient: patient) }

  let(:query) do
    <<~GQL
      query($id: ID!) {
        appointment(id: $id) { medicalRecord { id diagnosis notes } }
      }
    GQL
  end

  it "lets the responsible doctor read it and writes one audit row" do
    body = graphql(query, user: doctor.user, variables: { id: appointment.id })

    expect(graphql_data(body, "appointment", "medicalRecord", "diagnosis")).to eq("Essential hypertension")

    log = AuditLog.sole
    expect(log.user).to eq(doctor.user)
    expect(log.resource).to eq(record)
    expect(log.action).to eq("medical_record.read")
    expect(log.ip_address).to be_present
  end

  it "lets the patient read their own record" do
    body = graphql(query, user: patient.user, variables: { id: appointment.id })

    expect(graphql_data(body, "appointment", "medicalRecord", "notes")).to include("amlodipine")
  end

  it "hides another patient's record behind a null appointment, leaking nothing" do
    intruder = create(:patient)

    body = graphql(query, user: intruder.user, variables: { id: appointment.id })

    expect(graphql_data(body, "appointment")).to be_nil
    expect(response.body).not_to include("hypertension")
    expect(AuditLog.count).to be_zero
  end

  it "hides the record from a doctor who was not the one in the room" do
    bystander = create(:doctor)
    create(:appointment, patient: patient, availability: create(:availability, doctor: bystander), doctor: bystander)

    body = graphql(query, user: bystander.user, variables: { id: appointment.id })

    expect(graphql_data(body, "appointment")).to be_nil
    expect(response.body).not_to include("hypertension")
  end

  it "audits one read per record even when the query asks for both PHI fields" do
    graphql(query, user: doctor.user, variables: { id: appointment.id })

    expect(AuditLog.count).to eq(1)
  end

  describe "addMedicalRecord" do
    let(:appointment_without_record) do
      create(:appointment, patient: patient, availability: create(:availability, doctor: doctor), doctor: doctor)
    end

    let(:mutation) do
      <<~GQL
        mutation($id: ID!, $d: String!, $n: String) {
          addMedicalRecord(appointmentId: $id, diagnosis: $d, notes: $n) {
            resource { id diagnosis }
            errors { field code message }
          }
        }
      GQL
    end

    it "lets the responsible doctor file it" do
      body = graphql(mutation, user: doctor.user,
                               variables: { id: appointment_without_record.id, d: "Migraine", n: "Sumatriptan as needed" })

      expect(graphql_data(body, "addMedicalRecord", "errors")).to be_empty
      expect(graphql_data(body, "addMedicalRecord", "resource", "diagnosis")).to eq("Migraine")
      expect(AuditLog.where(action: "medical_record.create").count).to eq(1)
    end

    it "refuses a patient trying to author their own chart" do
      body = graphql(mutation, user: patient.user, variables: { id: appointment_without_record.id, d: "Self diagnosis", n: nil })

      expect(graphql_data(body, "addMedicalRecord", "errors").sole["code"]).to eq("not_responsible_doctor")
      expect(MedicalRecord.count).to eq(1)
    end

    it "refuses a second record for the same appointment" do
      body = graphql(mutation, user: doctor.user, variables: { id: appointment.id, d: "Duplicate", n: nil })

      expect(graphql_data(body, "addMedicalRecord", "errors").sole["code"]).to eq("record_exists")
    end
  end
end
