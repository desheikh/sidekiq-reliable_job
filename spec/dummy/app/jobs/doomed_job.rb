# frozen_string_literal: true

# A job that always fails and will eventually die
class DoomedJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true, queue: "default", retry: 2

  def perform(reason = "destiny")
    sleep rand(0.1..0.2)
    Rails.logger.error "[DoomedJob] Failing: #{reason}"
    raise "Doomed to fail: #{reason}"
  end
end
