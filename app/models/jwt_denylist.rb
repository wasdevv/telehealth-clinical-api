# Revocation store for issued JWTs. A token is valid until its jti lands here, which is
# what makes logout mean something for a stateless token.
class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  # Rows past their own expiry can never deny anything: the token they name is already
  # rejected on signature/exp. ExpiredTokenSweeper calls this daily.
  def self.prune_expired!(now = Time.current)
    where(exp: ...now).delete_all
  end
end
