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

  config.error_handlers.clear
  config.error_handlers << lambda { |ex, ctx, _cfg|
    job_class = ctx.dig(:job, "wrapped") || ctx.dig(:job, "class")

    if job_class.to_s.match?(/Flaky|Doomed/)
      Sidekiq.logger.warn "[#{job_class}] #{ex.message}"
    else
      Sidekiq.logger.error "#{ex.class}: #{ex.message}\n#{ex.backtrace&.first(5)&.join("\n")}"
    end
  }
end
