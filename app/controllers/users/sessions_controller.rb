module Users
  class SessionsController < Devise::SessionsController
    skip_before_action :verify_signed_out_user, raise: false
    before_action :authenticate_user!, only: :destroy

    # POST /auth/login
    def create
      user = User.find_by(email: login_params[:email].to_s.strip.downcase)

      # One branch, one message, one shape for "no such account" and "wrong password":
      # the response must not tell an attacker which emails exist.
      return render_error(:invalid_credentials, "Invalid email or password.", :unauthorized) unless
        user&.valid_password?(login_params[:password])

      if user.otp_enabled?
        # Deliberately no token here. The password alone is one factor; it buys a
        # short-lived, single-purpose challenge, nothing that opens /graphql.
        return render json: {
          two_factor_required: true,
          challenge: TwoFactor::Challenge.issue(user),
          expires_in: TwoFactor::Challenge::EXPIRY.to_i
        }, status: :accepted
      end

      token = issue_jwt(user)
      render json: { token: token, user: user_payload(user) }, status: :ok
    end

    # DELETE /auth/logout
    def destroy
      token = Warden::JWTAuth::HeaderParser.from_env(request.env)
      return render_error(:missing_token, "No bearer token to revoke.", :bad_request) if token.blank?

      payload = Warden::JWTAuth::TokenDecoder.new.call(token)
      JwtDenylist.revoke_jwt(payload, current_user)
      head :no_content
    rescue JWT::DecodeError
      render_error(:invalid_token, "The bearer token could not be decoded.", :unauthorized)
    end

    private

    def login_params
      params.expect(user: %i[email password])
    end
  end
end
