# frozen_string_literal: true

require "sidekiq/reliable_job"

# Ensure ActiveJob adapter is loaded (defines Sidekiq::ActiveJob::Wrapper)
# This is needed so Sidekiq can process ActiveJob jobs
require "active_job/queue_adapters/sidekiq_adapter"

Sidekiq.configure_client do |config|
  Sidekiq::ReliableJob.configure_client!(config)
end

Sidekiq.configure_server do |config|
  Sidekiq::ReliableJob.configure_server!(config)
end
