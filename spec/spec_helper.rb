# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# Load Rails from the dummy app
dummy_app_path = File.expand_path("dummy", __dir__)
require File.join(dummy_app_path, "config/environment")

require "rspec/rails"
require "factory_bot_rails"
require "sidekiq/reliable_job"
require "sidekiq/testing"

# Load support files
Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

# Tell FactoryBot where to find factories
FactoryBot.definition_file_paths = [File.expand_path("factories", __dir__)]
FactoryBot.find_definitions

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.use_transactional_fixtures = true

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed

  # Maintain test schema
  ActiveRecord::Migration.maintain_test_schema!

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include ActiveSupport testing helpers
  config.include ActiveSupport::Testing::TimeHelpers

  # Use Sidekiq fake mode by default and clear queues between tests
  # Skip setting fake! if already in disabled mode (for integration tests)
  config.before do
    Sidekiq::Testing.fake! unless Sidekiq::Testing.disabled?
    Sidekiq::Queues.clear_all
  end

  # Clean up staged jobs table before each test
  config.before do
    Sidekiq::ReliableJob::Outbox.delete_all
  end

  # Clean up Redis queues after tests that use real Redis
  config.after do
    Sidekiq.redis do |conn|
      keys = conn.keys("queue:*")
      conn.del(*keys) if keys.any?
    end
  end
end
