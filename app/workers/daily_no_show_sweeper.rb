# Closes out appointments whose time came and went while they were still merely
# "scheduled" — nobody confirmed, nobody completed them.
#
# There is deliberately no `no_show` status: the domain's four statuses are fixed by the
# schema's check constraint, and inventing a fifth one here to match this class's name
# would silently change the contract every other component reads. A swept appointment
# becomes `cancelled` with the reason recorded, which is expressible today.
#
# The invoice is *not* voided. A patient who does not appear still consumed the doctor's
# hour, so a no-show stays billable; cancelling through the API is what voids an invoice.
class DailyNoShowSweeper
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 3

  REASON = "no_show".freeze
  # An appointment is only swept once it is safely over, not the minute it starts.
  GRACE_PERIOD = 2.hours
  BATCH_SIZE = 500

  def perform
    cutoff = Time.current - GRACE_PERIOD
    swept = 0

    Appointment.where(status: "scheduled").where(ends_at: ...cutoff).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      swept += Appointment.where(id: batch.map(&:id)).update_all(
        status: "cancelled", cancelled_at: Time.current, cancellation_reason: REASON, updated_at: Time.current
      )
    end

    Rails.logger.info("DailyNoShowSweeper swept #{swept} appointment(s)")
    swept
  end
end
