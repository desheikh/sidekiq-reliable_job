# frozen_string_literal: true

module Sidekiq
  module ReliableJob
    def self.base_class
      @base_class ||= configuration.base_class.constantize
    end

    # ActiveRecord model for the job staging table.
    class Outbox < base_class
      self.table_name = "reliable_job_outbox"

      PENDING = "pending"
      ENQUEUED = "enqueued"
      DEAD = "dead"

      scope :pending, -> { where(status: PENDING) }
      scope :enqueued, -> { where(status: ENQUEUED) }
      scope :dead, -> { where(status: DEAD) }
    end
  end
end
