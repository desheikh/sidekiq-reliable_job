# frozen_string_literal: true

require "active_record"

module Sidekiq
  module ReliableJob
    def self.base_class
      @base_class ||= Sidekiq::ReliableJob.configuration.base_class.constantize
    end

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
