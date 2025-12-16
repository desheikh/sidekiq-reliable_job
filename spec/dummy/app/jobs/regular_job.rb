# frozen_string_literal: true

class RegularJob
  include Sidekiq::Job

  def perform(message)
    Rails.logger.info "RegularJob performed with: #{message}"
  end
end
