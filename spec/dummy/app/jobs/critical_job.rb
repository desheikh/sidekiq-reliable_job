# frozen_string_literal: true

# A critical job on a separate queue
class CriticalJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true, queue: "critical"

  def perform(priority_level = "high")
    Rails.logger.info "[CriticalJob] Processing critical task with priority=#{priority_level}"
    sleep rand(0.2..0.5)
    Rails.logger.info "[CriticalJob] Critical task completed"
  end
end
