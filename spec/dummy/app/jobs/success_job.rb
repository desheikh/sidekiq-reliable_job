# frozen_string_literal: true

# A job that always succeeds - reliable
class SuccessJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true, queue: "default"

  def perform(message = nil)
    sleep rand(0.1..0.5)
    Rails.logger.info "[SuccessJob] Completed successfully: #{message || 'no message'}"
  end
end
