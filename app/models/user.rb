class User < ApplicationRecord
  include TwoFactorAuthenticatable

  ROLES = %w[patient doctor admin].freeze

  # No :recoverable, :rememberable or :confirmable: this service sends nothing itself,
  # and no :registerable, because accounts are provisioned, not self-signed-up.
  devise :database_authenticatable, :validatable, :omniauthable, :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist,
         omniauth_providers: [:google_oauth2]

  has_one :patient, dependent: :destroy
  has_one :doctor, dependent: :destroy
  # Audit rows outlive the account they describe; deleting a user must not erase the
  # record of who read what.
  has_many :audit_logs, dependent: :restrict_with_exception

  normalizes :email, with: ->(value) { value.to_s.strip.downcase }

  validates :role, inclusion: { in: ROLES }
  validates :uid, uniqueness: { scope: :provider }, if: -> { provider.present? }

  ROLES.each do |name|
    define_method(:"#{name}?") { role == name }
  end

  scope :doctors, -> { where(role: "doctor") }

  def profile
    patient || doctor
  end

  # Google hands us a verified email. An account that already exists keeps its password
  # and its role; we only attach the provider identity to it. We never create an account
  # from an unverified email, and linking never downgrades an enabled second factor.
  def self.link_or_create_from_google(auth)
    email = auth.info.email.to_s.strip.downcase
    raise ArgumentError, "unverified google email" unless auth.info.email_verified || auth.extra&.dig(:raw_info, :email_verified)

    user = find_by(email: email) || new(email: email, role: "patient", password: Devise.friendly_token(48))
    user.provider = auth.provider
    user.uid = auth.uid
    user.save!
    user
  end
end
