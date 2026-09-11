source "https://rubygems.org"

gem "rails", "~> 8.1.3"

# Compatibility pin, not a preference. ActiveSupport 8.1.3.1 calls
# `JSON.parse(source, options)` with a positional Hash; json 3.x made those options
# keyword-only, so every JSON request body raises ArgumentError on Ruby 3.4.
# Remove once ActiveSupport switches to keyword arguments.
gem "json", "~> 2.9"

# Data stores. PostgreSQL holds the clinical domain; Redis backs Sidekiq and the cache.
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "redis", "~> 5.4"

# GraphQL is the only door into the domain (see README "Design decisions").
gem "batch-loader", "~> 2.0"
gem "graphql", "~> 2.5"

# Authentication: password + Google OAuth, JWT issued on login and revoked through a denylist.
gem "devise", "~> 4.9"
gem "devise-jwt", "~> 0.12"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-rails_csrf_protection", "~> 1.0"

# TOTP second factor.
gem "rotp", "~> 6.3"
gem "rqrcode", "~> 3.1"

# Background work: named queues plus cron, on Redis.
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 2.0"

# Business rules live in interactors, not in resolvers or models.
gem "interactor-rails", "~> 2.3"

gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  # Makes the documented `cp .env.example .env` actually do something. Without it the
  # app falls back to localhost defaults, which on a machine already running other
  # projects means quietly connecting to somebody else's Redis.
  gem "dotenv-rails", "~> 3.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "rspec-rails", "~> 8.0"
  gem "rubocop-rails", require: false
end

group :test do
  gem "rspec-sidekiq", "~> 5.1"
  gem "webmock", "~> 3.25"
end
