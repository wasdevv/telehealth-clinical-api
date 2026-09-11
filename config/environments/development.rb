require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  config.action_controller.perform_caching = false
  config.cache_store = :memory_store

  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true
  config.active_job.verbose_enqueue_logs = true

  config.action_controller.raise_on_missing_callback_actions = true

  # Development-only defaults so `bin/rails c` works without a populated .env.
  # Production and staging must supply real keys; see config/initializers/encryption_keys.rb.
  config.hosts.clear
end
