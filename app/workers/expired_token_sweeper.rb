# The denylist only ever grows otherwise: every logout adds a row that stays forever,
# even though a token past its own expiry is already refused on `exp`.
class ExpiredTokenSweeper
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 3

  def perform
    JwtDenylist.prune_expired!
  end
end
