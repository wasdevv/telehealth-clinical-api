# Active Record Encryption and the JWT signing key have no safe default. Outside
# development and test the process refuses to boot without them, so a missing
# secret is a loud crash at deploy time instead of a silently unprotected column.
required_secrets = %w[
  ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
  ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
  ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  DEVISE_JWT_SECRET_KEY
].freeze

Rails.application.config.to_prepare do
  next if Rails.env.local?

  missing = required_secrets.select { |key| ENV[key].blank? }
  raise "Missing required secrets: #{missing.join(', ')}" if missing.any?
end

if Rails.env.local?
  # Fixed, worthless, well-known values so `bin/rails c` and `rspec` work out of the
  # box. They are only reachable when RAILS_ENV is development or test.
  # `.presence ||`, never `||`: a key that is present but blank — an empty line in a
  # copied .env — must fall back like a missing one, not configure empty-key encryption.
  ActiveRecord::Encryption.configure(
    primary_key: ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence || "development_primary_key_not_a_secret",
    deterministic_key: ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence || "development_deterministic_key_not_a_secret",
    key_derivation_salt: ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence || "development_salt_not_a_secret"
  )
end
