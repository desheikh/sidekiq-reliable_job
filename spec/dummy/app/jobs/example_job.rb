# frozen_string_literal: true

class ExampleJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true

  def perform(message)
    Rails.logger.info "ExampleJob performed with: #{message}"
  end
end
