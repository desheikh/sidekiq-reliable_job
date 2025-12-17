# frozen_string_literal: true

# An ActiveJob that fails randomly - simulates flaky behavior
class ActiveFlakyJob < ApplicationJob
  queue_as :default
  sidekiq_options reliable_job: true, retry: 5

  def perform(fail_rate = 0.7)
    sleep rand(0.1..0.3)

    if rand < fail_rate.to_f
      Rails.logger.warn "[ActiveFlakyJob] Failing randomly (fail_rate: #{fail_rate})"
      raise "Random ActiveJob flaky failure!"
    end

    Rails.logger.info "[ActiveFlakyJob] Succeeded after potential retries"
  end
end
