# The test suite must never point at the development database. `||=` would let an
# inherited RAILS_ENV win; assignment is the whole guard.
ENV["RAILS_ENV"] = "test"

require "spec_helper"
require File.expand_path("../config/environment", __dir__)

abort("The Rails environment is running in #{Rails.env}, not test.") unless Rails.env.test?

require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
