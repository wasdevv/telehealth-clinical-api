source "https://rubygems.org"

gem "rails", "~> 8.1.3"

# Data stores. PostgreSQL holds the clinical domain; Redis backs Sidekiq and the cache.
gem "pg", "~> 1.5"
gem "redis", "~> 5.4"
gem "puma", ">= 6.0"

# GraphQL is the only door into the domain (see README "Design decisions").
gem "graphql", "~> 2.5"
gem "batch-loader", "~> 2.0"

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
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rubocop-rails", require: false
  gem "brakeman", require: false
end

group :test do
  gem "webmock", "~> 3.25"
  gem "rspec-sidekiq", "~> 5.1"
end
