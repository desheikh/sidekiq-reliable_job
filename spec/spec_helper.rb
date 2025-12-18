# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require File.expand_path("dummy/config/environment", __dir__)
require "rspec/rails"
require "factory_bot_rails"
require "sidekiq/reliable_job"
require "sidekiq/testing"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

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

  ActiveRecord::Migration.maintain_test_schema!

  config.include RedisHelpers
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers

  config.before do
    Sidekiq::Testing.fake! unless Sidekiq::Testing.disabled?
    Sidekiq::Queues.clear_all
    Sidekiq::ReliableJob::Outbox.delete_all
    Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false
  end
end
