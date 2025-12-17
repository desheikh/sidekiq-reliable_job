# frozen_string_literal: true

class ExampleActiveJob < ApplicationJob
  queue_as :default

  # Enable reliable job for this ActiveJob
  sidekiq_options reliable_job: true

  def perform(message)
    Rails.logger.info "ExampleActiveJob performed with: #{message}"
  end
end
