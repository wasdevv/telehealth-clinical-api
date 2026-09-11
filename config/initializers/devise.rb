Devise.setup do |config|
  require "devise/orm/active_record"

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.password_length = 12..128
  config.stretches = Rails.env.test? ? 1 : 12
  config.reload_routes = false

  # This service has no browser flows: there is nothing to redirect to and no session to
  # fall back on, so a failed authentication is a 401 with a JSON body.
  config.navigational_formats = []
  config.skip_session_storage = %i[http_auth params_auth]
  config.sign_out_via = :delete

  # Google is the only provider. The path prefix keeps the URLs at /auth/google_oauth2
  # instead of Devise's default /users/auth/... .
  config.omniauth_path_prefix = "/auth"
  config.omniauth :google_oauth2,
                  ENV["GOOGLE_CLIENT_ID"].to_s,
                  ENV["GOOGLE_CLIENT_SECRET"].to_s,
                  scope: "email,profile",
                  prompt: "select_account"

  config.jwt do |jwt|
    jwt.secret = ENV["DEVISE_JWT_SECRET_KEY"].presence || Rails.application.secret_key_base
    jwt.expiration_time = (ENV["JWT_EXPIRATION_SECONDS"].presence || 1.hour.to_i).to_i

    # Tokens are minted by the controllers (Users::SessionsController, TwoFactorController,
    # Users::OmniauthCallbacksController) rather than by matching request paths here. An
    # account with 2FA enabled must not receive a token from the password step, and a
    # path regexp cannot express that condition. Revocation is equally explicit.
    jwt.dispatch_requests = []
    jwt.revocation_requests = []
  end
end
