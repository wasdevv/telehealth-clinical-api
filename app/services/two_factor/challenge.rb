module TwoFactor
  # The token handed out after a correct password when the account has a second factor.
  # It is signed with the app's secret, expires on its own, and is bound to one purpose,
  # so it cannot be replayed as a session token or reused for another endpoint.
  module Challenge
    EXPIRY = 5.minutes
    PURPOSE = "two_factor_login".freeze

    def self.issue(user)
      verifier.generate({ "user_id" => user.id }, expires_in: EXPIRY, purpose: PURPOSE)
    end

    def self.user_for(token)
      data = verifier.verified(token.to_s, purpose: PURPOSE)
      return nil unless data.is_a?(Hash)

      User.find_by(id: data["user_id"])
    end

    def self.verifier
      Rails.application.message_verifier("two_factor_challenge")
    end
  end
end
