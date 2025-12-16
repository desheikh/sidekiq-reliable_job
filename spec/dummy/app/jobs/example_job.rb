# frozen_string_literal: true

class ExampleJob
  include Sidekiq::Job
  include Sidekiq::ReliableJob::JobExtension

  def perform(message)
    Rails.logger.info "ExampleJob performed with: #{message}"
  end
end
