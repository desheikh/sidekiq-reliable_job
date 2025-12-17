# frozen_string_literal: true

# A job that fails randomly - simulates flaky behavior
# Will eventually succeed after a few retries
class FlakyJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true, queue: "default", retry: 5

  def perform(fail_rate = 0.7)
    sleep rand(0.1..0.3)

    if rand < fail_rate.to_f
      Rails.logger.warn "[FlakyJob] Failing randomly (fail_rate: #{fail_rate})"
      raise "Random flaky failure!"
    end

    Rails.logger.info "[FlakyJob] Succeeded after potential retries"
  end
end
