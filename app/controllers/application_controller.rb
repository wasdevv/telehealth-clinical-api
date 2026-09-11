class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  private

  def render_error(code, message, status)
    render json: { errors: [{ code: code.to_s, message: message }] }, status: status
  end

  def render_record_invalid(exception)
    render json: {
      errors: exception.record.errors.map do |error|
        { field: error.attribute.to_s, code: error.type.to_s, message: error.full_message }
      end
    }, status: :unprocessable_content
  end

  # The bearer token is minted here rather than by devise-jwt's path-matching middleware,
  # so that "password accepted" and "token issued" stay separable for 2FA accounts.
  def issue_jwt(user)
    token, _payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    response.set_header("Authorization", "Bearer #{token}")
    token
  end

  def user_payload(user)
    {
      id: user.id,
      email: user.email,
      role: user.role,
      two_factor_enabled: user.otp_enabled
    }
  end
end
