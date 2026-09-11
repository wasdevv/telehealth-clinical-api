require "sidekiq"
require "sidekiq-cron"

redis_config = { url: ENV["REDIS_URL"].presence || "redis://localhost:6379/0" }.freeze

Sidekiq.configure_server do |config|
  config.redis = redis_config

  config.on(:startup) do
    schedule_file = Rails.root.join("config/schedule.yml")
    next unless schedule_file.exist?

    # Loading on server startup — rather than from an initializer — means the cron
    # entries are registered by the process that will actually run them, and a web-only
    # boot never touches the schedule.
    Sidekiq::Cron::Job.load_from_hash!(YAML.load_file(schedule_file), source: "schedule.yml")
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
