# The retry path for voiding an invoice after a cancellation. A cancellation is clinically
# valid the moment it is recorded; billing catching up is a background concern.
class BillingVoidWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 10

  def perform(external_ref)
    BillingClient.new.void_invoice(external_ref)
  end
end
