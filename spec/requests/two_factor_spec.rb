require "rails_helper"

RSpec.describe "Two-factor authentication", type: :request do
  let(:password) { "correct-horse-battery-staple" }
  let!(:user) { create(:user, email: "sam@example.com", password: password) }

  def current_code(secret)
    ROTP::TOTP.new(secret).now
  end

  describe "POST /auth/2fa/setup" do
    it "returns a provisioning URI and a QR code without enabling anything" do
      post "/auth/2fa/setup", headers: auth_headers(user)

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body["otpauth_uri"]).to start_with("otpauth://totp/")
      expect(body["qr_code_svg"]).to include("<svg")
      expect(user.reload.otp_enabled).to be(false)
    end
  end

  describe "POST /auth/2fa/enable" do
    before { post "/auth/2fa/setup", headers: auth_headers(user) }

    it "refuses a wrong code" do
      post "/auth/2fa/enable", params: { code: "000000" }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.otp_enabled).to be(false)
    end

    it "enables the factor and returns recovery codes exactly once" do
      secret = user.reload.otp_secret

      post "/auth/2fa/enable", params: { code: current_code(secret) }, headers: auth_headers(user), as: :json

      codes = response.parsed_body["recovery_codes"]
      expect(response).to have_http_status(:ok)
      expect(codes.size).to eq(User::RECOVERY_CODE_COUNT)
      expect(user.reload.otp_enabled).to be(true)

      # Only digests survive: the plaintext is gone the moment the response is sent.
      expect(user.otp_recovery_code_digests).to match_array(codes.map { |c| User.recovery_code_digest(c) })
      expect(user.otp_recovery_code_digests).not_to include(*codes)
    end
  end

  describe "login with the factor enabled" do
    let!(:secret) { ROTP::Base32.random }

    before { user.update!(otp_secret: secret, otp_enabled: true) }

    it "issues a challenge instead of a token" do
      post "/auth/login", params: { user: { email: user.email, password: password } }, as: :json

      body = response.parsed_body
      expect(response).to have_http_status(:accepted)
      expect(body["two_factor_required"]).to be(true)
      expect(body["challenge"]).to be_present
      expect(body).not_to have_key("token")
      expect(response.headers["Authorization"]).to be_nil
    end

    it "exchanges a correct code for a token" do
      post "/auth/login", params: { user: { email: user.email, password: password } }, as: :json
      challenge = response.parsed_body["challenge"]

      post "/auth/2fa/verify", params: { challenge: challenge, code: current_code(secret) }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["token"]).to be_present
    end

    it "refuses a wrong code" do
      post "/auth/login", params: { user: { email: user.email, password: password } }, as: :json
      challenge = response.parsed_body["challenge"]

      post "/auth/2fa/verify", params: { challenge: challenge, code: "000000" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses a replayed code" do
      post "/auth/login", params: { user: { email: user.email, password: password } }, as: :json
      challenge = response.parsed_body["challenge"]
      code = current_code(secret)

      post "/auth/2fa/verify", params: { challenge: challenge, code: code }, as: :json
      expect(response).to have_http_status(:ok)

      post "/auth/2fa/verify", params: { challenge: challenge, code: code }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses an expired challenge" do
      post "/auth/login", params: { user: { email: user.email, password: password } }, as: :json
      challenge = response.parsed_body["challenge"]

      travel(TwoFactor::Challenge::EXPIRY + 1.minute) do
        post "/auth/2fa/verify", params: { challenge: challenge, code: current_code(secret) }, as: :json
      end

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts a recovery code once and never again" do
      user.update!(otp_recovery_code_digests: [User.recovery_code_digest("rescue-me-01")])
      post "/auth/login", params: { user: { email: user.email, password: password } }, as: :json
      challenge = response.parsed_body["challenge"]

      post "/auth/2fa/verify", params: { challenge: challenge, recovery_code: "rescue-me-01" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(user.reload.otp_recovery_code_digests).to be_empty

      post "/auth/2fa/verify", params: { challenge: challenge, recovery_code: "rescue-me-01" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
