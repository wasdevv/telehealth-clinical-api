module Appointments
  # Cancels an appointment on behalf of one of its participants.
  #
  # Expects: context.current_user, context.appointment_id, optional context.reason
  # Provides: context.appointment
  class Cancel
    include ApplicationInteractor

    def call
      # Scoped lookup, not lookup-then-authorise: an appointment belonging to someone else
      # is simply not found, so the response cannot be used to probe for other people's ids.
      @appointment = Appointment.visible_to(context.current_user).find_by(id: context.appointment_id)
      fail_with(:id, :not_found, "That appointment does not exist.") if @appointment.nil?

      cancel_record
      publish_cancellation
      context.appointment = @appointment
    end

    # Restores the status the appointment had before this interactor changed it. The
    # invoice void is deliberately not undone: re-creating an invoice the patient was
    # already told was cancelled is worse than leaving billing to reconcile.
    def rollback
      return if context.previous_status.blank?

      @appointment&.update_columns(
        status: context.previous_status,
        cancelled_at: nil,
        cancellation_reason: nil,
        updated_at: Time.current
      )
    end

    private

    def cancel_record
      @appointment.with_lock do
        unless @appointment.active?
          fail_with(:status, :not_cancellable, "An appointment that is #{@appointment.status} cannot be cancelled.")
        end

        context.previous_status = @appointment.status
        @appointment.update!(
          status: "cancelled",
          cancelled_at: Time.current,
          cancellation_reason: context.reason.presence
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      fail_with_record(e.record)
    end

    # After the commit, for the same reason as in Book. A cancellation is clinically valid
    # the moment it is recorded; billing is never allowed to veto it.
    def publish_cancellation
      BillingClient.new.void_invoice(@appointment.external_ref)
    rescue InternalServiceClient::Error
      BillingVoidWorker.perform_in(30.seconds, @appointment.external_ref)
    end
  end
end
