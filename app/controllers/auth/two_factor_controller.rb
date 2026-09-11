module Auth
  class TwoFactorController < ApplicationController
    before_action :authenticate_user!, only: %i[setup enable]

    # POST /auth/2fa/setup — authenticated. Starts enrolment; does not enable anything.
    def setup
      current_user.start_totp_enrollment!

      render json: {
        otpauth_uri: current_user.otp_provisioning_uri,
        qr_code_svg: current_user.otp_qr_code_svg
      }, status: :ok
    end

    # POST /auth/2fa/enable — authenticated. A correct code proves the phone holds the
    # secret; only then does the factor go live, and only then are recovery codes issued.
    def enable
      codes = current_user.enable_two_factor!(params[:code])
      return render_error(:invalid_code, "That code is not valid.", :unprocessable_entity) if codes.nil?

      # The one and only time these leave the server.
      render json: { two_factor_enabled: true, recovery_codes: codes }, status: :ok
    end

    # POST /auth/2fa/verify — unauthenticated, holds the challenge from the login step.
    def verify
      user = TwoFactor::Challenge.user_for(params[:challenge])
      return render_error(:invalid_challenge, "The challenge is missing, expired or invalid.", :unauthorized) if user.nil?

      return render_error(:two_factor_not_enabled, "This account has no second factor.", :unprocessable_entity) unless
        user.otp_enabled?

      unless user.verify_totp?(params[:code]) || user.consume_recovery_code?(params[:recovery_code])
        return render_error(:invalid_code, "That code is not valid.", :unauthorized)
      end

      token = issue_jwt(user)
      render json: { token: token, user: user_payload(user) }, status: :ok
    end
  end
end
