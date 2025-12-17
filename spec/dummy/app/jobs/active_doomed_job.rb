# frozen_string_literal: true

# An ActiveJob that always fails and will eventually die
class ActiveDoomedJob < ApplicationJob
  queue_as :default
  sidekiq_options reliable_job: true, retry: 2

  def perform(reason = "ActiveJob destiny")
    sleep rand(0.1..0.2)
    Rails.logger.error "[ActiveDoomedJob] Failing: #{reason}"
    raise "ActiveJob doomed to fail: #{reason}"
  end
end
