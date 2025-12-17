# frozen_string_literal: true

# A job that takes a while to complete
class SlowJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true, queue: "default"

  def perform(duration = 2)
    Rails.logger.info "[SlowJob] Starting, will take #{duration}s"
    sleep duration.to_f
    Rails.logger.info "[SlowJob] Completed after #{duration}s"
  end
end
