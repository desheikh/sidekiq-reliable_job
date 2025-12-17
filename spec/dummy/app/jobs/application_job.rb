# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Use Sidekiq as the queue adapter
  self.queue_adapter = :sidekiq
end
