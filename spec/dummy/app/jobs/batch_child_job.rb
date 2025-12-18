# frozen_string_literal: true

class BatchChildJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true

  def perform(item_id)
    Rails.logger.info "BatchChildJob processing item #{item_id}"
    sleep 0.1
  end
end
