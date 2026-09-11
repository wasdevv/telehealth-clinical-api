module Appointments
  # Books one availability for one patient.
  #
  # Expects: context.patient, context.availability_id
  # Provides: context.appointment, context.invoice_deferred
  class Book
    include ApplicationInteractor

    def call
      @patient = context.patient
      fail_with(:patient, :missing_profile, "This account has no patient profile.") if @patient.nil?

      @availability = Availability.find_by(id: context.availability_id)
      fail_with(:availabilityId, :not_found, "That availability does not exist.") if @availability.nil?

      reserve_slot
      publish_booking
    end

    # Compensation for a booking that was created and then had to be undone. It is not a
    # substitute for the database transaction below — that one has already committed by
    # the time anything here can run. Undoing a committed booking means recording a
    # cancellation and asking billing to void, not deleting history.
    def rollback
      appointment = context.appointment
      return if appointment.nil?

      appointment.update_columns(
        status: "cancelled",
        cancelled_at: Time.current,
        cancellation_reason: "booking_rolled_back",
        updated_at: Time.current
      )
      BillingVoidWorker.perform_async(appointment.external_ref) if context.invoice_created
    end

    private

    def reserve_slot
      # SELECT ... FOR UPDATE on the availability row. Two simultaneous requests for the
      # same slot are serialised here: the second one blocks until the first commits, and
      # then sees the appointment the first one created. Without the lock both would read
      # "no active appointment" and both would insert.
      @availability.with_lock do
        fail_with(:availabilityId, :in_the_past, "That slot has already started.") if @availability.starts_at <= Time.current

        if Appointment.active.exists?(availability_id: @availability.id)
          fail_with(:availabilityId, :slot_taken, "That slot is already booked.")
        end

        context.appointment = Appointment.create!(
          patient: @patient,
          doctor_id: @availability.doctor_id,
          availability: @availability,
          starts_at: @availability.starts_at,
          ends_at: @availability.ends_at,
          status: "scheduled"
        )
      end
    rescue ActiveRecord::RecordNotUnique
      # The partial unique index caught what the lock is meant to prevent. Reaching here
      # means some other path inserted without taking the lock; the patient still gets a
      # clean domain error rather than a 500.
      fail_with(:availabilityId, :slot_taken, "That slot is already booked.")
    rescue ActiveRecord::RecordInvalid => e
      fail_with_record(e.record)
    end

    # Everything below runs *after* the transaction has committed. A job enqueued inside
    # the transaction can be picked up by a Sidekiq worker before the commit lands — or
    # survive a rollback entirely — and an HTTP call made inside it cannot be undone at
    # all. Redis and the Django service have never heard of our transaction.
    def publish_booking
      schedule_reminder
      create_invoice
    end

    def schedule_reminder
      appointment = context.appointment
      remind_at = appointment.reminder_time

      if remind_at.future?
        AppointmentReminderWorker.perform_at(remind_at, appointment.id)
      else
        # Booked inside the 24-hour window. Scheduling into the past would make Sidekiq
        # run it immediately anyway; saying so explicitly beats a nonsensical timestamp.
        AppointmentReminderWorker.perform_async(appointment.id)
      end
    end

    def create_invoice
      BillingClient.new.create_invoice(context.appointment)
      context.invoice_created = true
    rescue InternalServiceClient::RetryableError
      # A slow or unreachable billing service must not cost the patient their slot. The
      # retry carries the same idempotency key, so the invoice is created exactly once.
      BillingInvoiceWorker.perform_in(30.seconds, context.appointment.id)
      context.invoice_deferred = true
    rescue InternalServiceClient::UnprocessableError => e
      # Billing understood the request and refused it — an account on hold, say. That is
      # a real reason not to hold the slot, so the booking is compensated and reported.
      rollback
      fail_with(:billing, :invoice_rejected, "Billing refused this appointment: #{e.message}")
    rescue InternalServiceClient::ConfigurationError => e
      rollback
      fail_with(:billing, :billing_unavailable, e.message)
    end
  end
end
