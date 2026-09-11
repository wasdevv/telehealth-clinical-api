module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    # GET|POST /auth/google_oauth2/callback
    def google_oauth2
      user = User.link_or_create_from_google(request.env["omniauth.auth"])

      # OAuth proves one factor, exactly like a password does. An account that turned on
      # a second factor still has to present it; otherwise Google would be a way around it.
      if user.otp_enabled?
        return render json: {
          two_factor_required: true,
          challenge: TwoFactor::Challenge.issue(user),
          expires_in: TwoFactor::Challenge::EXPIRY.to_i
        }, status: :accepted
      end

      token = issue_jwt(user)
      render json: { token: token, user: user_payload(user) }, status: :ok
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      render_error(:oauth_rejected, e.message, :unprocessable_entity)
    end

    def failure
      render_error(:oauth_failed, failure_message.to_s.presence || "Google sign-in failed.", :unauthorized)
    end
  end
end
