# frozen_string_literal: true

require "sidekiq/reliable_job"

Sidekiq.configure_client do |config|
  Sidekiq::ReliableJob.configure_client!(config)
end

Sidekiq.configure_server do |config|
  Sidekiq::ReliableJob.configure_server!(config)
end
