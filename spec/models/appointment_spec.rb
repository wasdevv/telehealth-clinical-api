require "rails_helper"

RSpec.describe Appointment do
  it "generates external_ref from the primary key" do
    appointment = create(:appointment)

    expect(appointment.reload.external_ref).to eq("appointment:#{appointment.id}")
  end

  it "refuses a second active appointment on one availability at the database level" do
    first = create(:appointment)

    duplicate = {
      patient_id: create(:patient).id,
      doctor_id: first.doctor_id,
      availability_id: first.availability_id,
      starts_at: first.starts_at,
      ends_at: first.ends_at,
      status: "scheduled",
      created_at: Time.current,
      updated_at: Time.current
    }

    expect { described_class.insert_all!([duplicate]) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows rebooking once the first one is cancelled" do
    first = create(:appointment)
    first.update!(status: "cancelled", cancelled_at: Time.current)

    expect { create(:appointment, availability: first.availability, doctor: first.doctor) }.not_to raise_error
  end

  it "refuses an end time before the start time at the database level" do
    appointment = create(:appointment)

    expect { appointment.update_columns(ends_at: appointment.starts_at - 1.hour) }
      .to raise_error(ActiveRecord::StatementInvalid, /appointments_time_order_check/)
  end

  it "refuses a status outside the four the domain knows" do
    appointment = create(:appointment)

    expect { appointment.update_columns(status: "ghosted") }
      .to raise_error(ActiveRecord::StatementInvalid, /appointments_status_check/)
  end
end
