# TOTP second factor. The secret is encrypted at rest; recovery codes exist only as
# SHA256 digests, so a database dump cannot be replayed against the account.
module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  ISSUER = "Telehealth Clinical".freeze
  RECOVERY_CODE_COUNT = 10
  # One 30-second step of tolerance in each direction covers ordinary phone clock skew
  # without widening the window enough to matter to an attacker.
  DRIFT_SECONDS = 30

  included do
    encrypts :otp_secret
  end

  def start_totp_enrollment!
    # Enrolment replaces any half-finished attempt, and never touches otp_enabled:
    # a secret only becomes the account's second factor once a code proves the phone has it.
    update!(otp_secret: ROTP::Base32.random, otp_last_used_at: nil)
    otp_secret
  end

  def otp_provisioning_uri
    return nil if otp_secret.blank?

    ROTP::TOTP.new(otp_secret, issuer: ISSUER).provisioning_uri(email)
  end

  def otp_qr_code_svg
    uri = otp_provisioning_uri
    return nil if uri.nil?

    RQRCode::QRCode.new(uri).as_svg(module_size: 4, use_path: true, viewbox: true)
  end

  # Returns true only for a code that is current *and* has not been used before. ROTP
  # hands back the interval it matched, which is exactly the high-water mark to store.
  def verify_totp?(code)
    return false if otp_secret.blank? || code.blank?

    matched_at = ROTP::TOTP.new(otp_secret, issuer: ISSUER).verify(
      code.to_s.strip,
      drift_behind: DRIFT_SECONDS,
      drift_ahead: DRIFT_SECONDS,
      after: otp_last_used_at
    )
    return false if matched_at.nil?

    update_column(:otp_last_used_at, Time.at(matched_at).utc)
    true
  end

  # Turns enrolment into an enabled second factor and returns the plaintext recovery
  # codes. This is the only moment they exist outside the user's own records.
  def enable_two_factor!(code)
    return nil unless verify_totp?(code)

    codes = Array.new(RECOVERY_CODE_COUNT) { SecureRandom.alphanumeric(12).downcase }
    update!(otp_enabled: true, otp_recovery_code_digests: codes.map { |plain| self.class.recovery_code_digest(plain) })
    codes
  end

  def disable_two_factor!
    update!(otp_enabled: false, otp_secret: nil, otp_recovery_code_digests: [], otp_last_used_at: nil)
  end

  # Consumes one code under a row lock, so two requests racing with the same code cannot
  # both win. Comparison is constant-time to keep digests out of a timing oracle.
  def consume_recovery_code?(code)
    digest = self.class.recovery_code_digest(code)

    with_lock do
      remaining = otp_recovery_code_digests.dup
      index = remaining.index { |stored| ActiveSupport::SecurityUtils.secure_compare(stored, digest) }
      return false if index.nil?

      remaining.delete_at(index)
      update!(otp_recovery_code_digests: remaining)
      true
    end
  end

  def self.recovery_code_digest(code)
    Digest::SHA256.hexdigest(code.to_s.strip.downcase)
  end

  class_methods do
    delegate :recovery_code_digest, to: :TwoFactorAuthenticatable
  end
end
