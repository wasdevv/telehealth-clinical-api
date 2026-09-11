# Anything here is redacted from request logs. The list deliberately covers PHI
# (notes, diagnosis) and every second-factor artifact, not just passwords.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :email, :authorization, :jwt,
  :otp_secret, :otp_code, :recovery_code, :recovery_codes, :challenge,
  :notes, :diagnosis
]
