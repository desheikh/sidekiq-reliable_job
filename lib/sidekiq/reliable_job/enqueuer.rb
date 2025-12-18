# frozen_string_literal: true

require "sidekiq/component"

module Sidekiq
  module ReliableJob
    # Background thread that continuously processes the Outbox.
    class Enqueuer
      include Sidekiq::Component

      POLL_INTERVAL = 0.1
      ERROR_SLEEP = 1
      LOCK_RETRY_SLEEP = 20

      def initialize(config)
        @config = config
        @done = false
        @processor = OutboxProcessor.new
      end

      def start
        @thread = Thread.new { run }
      end

      def stop
        @done = true
      end

      private

      def run
        process_loop until @done
      end

      def process_loop
        count = @processor.call
        sleep POLL_INTERVAL if count.zero?
      rescue WithAdvisoryLock::FailedToAcquireLock
        sleep LOCK_RETRY_SLEEP
      rescue StandardError => e
        logger.error "ReliableJob::Enqueuer error: #{e.class} - #{e.message}"
        sleep ERROR_SLEEP
      end
    end
  end
end
