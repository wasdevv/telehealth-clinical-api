require "rails_helper"

RSpec.describe "Background workers" do
  describe AppointmentReminderWorker do
    let(:appointment) { create(:appointment) }

    it "sends the reminder in the contract's shape" do
      stub_reminder
      appointment.patient.update!(phone: "+15551234567")

      described_class.new.perform(appointment.id)

      expect(
        a_request(:post, "http://billing.test/api/v1/notifications/reminder/").with do |req|
          body = JSON.parse(req.body)
          body["email"] == appointment.patient.user.email &&
            body["phone"] == "+15551234567" &&
            body["doctor"] == appointment.doctor.full_name &&
            Time.iso8601(body["starts_at"]) == appointment.starts_at
        end
      ).to have_been_made.once
    end

    it "sends an empty string when the patient has no phone" do
      stub_reminder
      appointment.patient.update!(phone: nil)

      described_class.new.perform(appointment.id)

      expect(a_request(:post, "http://billing.test/api/v1/notifications/reminder/")
        .with { |req| JSON.parse(req.body)["phone"] == "" }).to have_been_made
    end

    it "stays quiet for a cancelled appointment" do
      appointment.update!(status: "cancelled")

      described_class.new.perform(appointment.id)

      expect(a_request(:post, "http://billing.test/api/v1/notifications/reminder/")).not_to have_been_made
    end

    it "stays quiet for an appointment that no longer exists" do
      expect { described_class.new.perform(-1) }.not_to raise_error
    end

    it "runs on the notifications queue" do
      expect(described_class.sidekiq_options["queue"]).to eq(:notifications)
    end
  end

  describe DailyNoShowSweeper do
    it "cancels a scheduled appointment whose time passed, with the reason recorded" do
      stale = create(:appointment, availability: create(:availability, :past))
      stale.update_columns(starts_at: 5.hours.ago, ends_at: 4.hours.ago)
      upcoming = create(:appointment)

      described_class.new.perform

      expect(stale.reload).to be_cancelled
      expect(stale.cancellation_reason).to eq("no_show")
      expect(upcoming.reload).to be_scheduled
    end

    it "leaves the invoice alone, because a no-show is still billable" do
      stale = create(:appointment, availability: create(:availability, :past))
      stale.update_columns(starts_at: 5.hours.ago, ends_at: 4.hours.ago)

      described_class.new.perform

      expect(BillingVoidWorker.jobs).to be_empty
    end

    it "runs on the maintenance queue" do
      expect(described_class.sidekiq_options["queue"]).to eq(:maintenance)
    end
  end

  describe BillingReconciliationWorker do
    it "re-submits invoices for recent active appointments and survives one failure" do
      good = create(:appointment)
      bad = create(:appointment, availability: create(:availability))

      stub_request(:post, "http://billing.test/api/v1/invoices/")
        .with { |req| JSON.parse(req.body)["external_ref"] == good.external_ref }
        .to_return(status: 200, body: "{}")
      stub_request(:post, "http://billing.test/api/v1/invoices/")
        .with { |req| JSON.parse(req.body)["external_ref"] == bad.external_ref }
        .to_return(status: 500, body: "{}")

      expect(described_class.new.perform).to eq(reconciled: 1, failed: 1)
    end
  end

  describe ExpiredTokenSweeper do
    it "deletes only the rows whose tokens already expired" do
      JwtDenylist.create!(jti: "old", exp: 1.hour.ago)
      JwtDenylist.create!(jti: "live", exp: 1.hour.from_now)

      described_class.new.perform

      expect(JwtDenylist.pluck(:jti)).to eq(["live"])
    end
  end
end
