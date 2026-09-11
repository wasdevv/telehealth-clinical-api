require_relative "boot"

require "rails"
# Only the frameworks this API actually uses. Action Cable, Action Mailbox, Action Text,
# Active Storage and the asset pipeline are absent by design: this service speaks JSON
# over one GraphQL endpoint and hands every outbound message to the billing service.
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module TelehealthClinicalApi
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.api_only = true
    config.time_zone = "UTC"

    # Background work goes to Sidekiq, never to the in-process async adapter.
    config.active_job.queue_adapter = :sidekiq

    config.cache_store = :redis_cache_store, {
      url: ENV["REDIS_URL"].presence || "redis://localhost:6379/1",
      namespace: "telehealth-clinical-api",
      error_handler: lambda { |method:, exception:, returning: nil|
        # A cache outage must degrade the API, never stop it.
        Rails.logger.warn("cache #{method} failed (returning #{returning.inspect}): #{exception.class}")
      }
    }

    # Active Record Encryption protects PHI (MedicalRecord#notes, #diagnosis) and the
    # TOTP secret. Keys always come from the environment; they are never committed.
    config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", nil)
    config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", nil)
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", nil)

    # OmniAuth's request phase needs a session to hold the OAuth state parameter, and
    # omniauth-rails_csrf_protection needs the CSRF token. API mode drops both by default.
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, key: "_telehealth_clinical_api_session", same_site: :lax

    config.generators do |g|
      g.test_framework :rspec, request_specs: false, view_specs: false, helper_specs: false, routing_specs: false
      g.factory_bot dir: "spec/factories"
    end
  end
end
