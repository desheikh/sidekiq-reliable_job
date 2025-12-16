# frozen_string_literal: true

require "sidekiq/reliable_job"

Sidekiq.configure_server do |config|
  Sidekiq::ReliableJob.configure_server!(config)
end
