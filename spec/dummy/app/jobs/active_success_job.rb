# frozen_string_literal: true

# An ActiveJob that always succeeds - reliable
class ActiveSuccessJob < ApplicationJob
  queue_as :default
  sidekiq_options reliable_job: true

  def perform(message = nil)
    sleep rand(0.1..0.5)
    Rails.logger.info "[ActiveSuccessJob] Completed successfully: #{message || 'no message'}"
  end
end
