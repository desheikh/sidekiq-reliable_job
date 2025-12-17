# frozen_string_literal: true

class RegularActiveJob < ApplicationJob
  queue_as :default

  def perform(message)
    Rails.logger.info "RegularActiveJob performed with: #{message}"
  end
end
