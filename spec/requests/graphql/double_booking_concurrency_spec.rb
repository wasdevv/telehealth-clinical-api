require "rails_helper"

RSpec.describe "Two requests racing for the same slot", type: :request do
  # Real threads on real connections: transactional fixtures would put each thread in its
  # own transaction and hide the very interleaving under test.
  self.use_transactional_tests = false

  let!(:doctor) { create(:doctor) }
  let!(:availability) { create(:availability, doctor: doctor) }
  let!(:patients) { create_list(:patient, 2) }

  before do
    stub_invoice_create
    stub_reminder
  end

  after do
    Appointment.delete_all
    MedicalRecord.delete_all
    Availability.delete_all
    Doctor.delete_all
    Patient.delete_all
    User.delete_all
  end

  it "lets exactly one of them win" do
    # Note what this does and does not prove. It proves the invariant end to end: under
    # genuine concurrency exactly one active appointment exists and the loser gets a clean
    # domain error. It does *not* prove the pessimistic lock on its own — deleting the
    # lock leaves this example green, because the partial unique index catches the loser
    # and RecordNotUnique maps to the same `slot_taken`. That the lock is taken at all is
    # asserted directly in spec/interactors/appointments/book_spec.rb.
    barrier = Concurrent::CyclicBarrier.new(patients.size)
    results = Concurrent::Array.new

    patients.map do |patient|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.wait
          results << Appointments::Book.call(patient: patient, availability_id: availability.id)
        end
      end
    end.each(&:join)

    expect(results.count(&:success?)).to eq(1)
    expect(results.count(&:failure?)).to eq(1)
    expect(results.find(&:failure?).errors.sole[:code]).to eq("slot_taken")
    expect(Appointment.active.where(availability_id: availability.id).count).to eq(1)
  end
end
