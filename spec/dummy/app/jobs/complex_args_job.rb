# frozen_string_literal: true

# A job with complex arguments
class ComplexArgsJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true, queue: "default"

  def perform(user_id, options = {})
    Rails.logger.info "[ComplexArgsJob] Processing user_id=#{user_id} with options=#{options}"
    sleep rand(0.1..0.3)
    Rails.logger.info "[ComplexArgsJob] Done processing user_id=#{user_id}"
  end
end
