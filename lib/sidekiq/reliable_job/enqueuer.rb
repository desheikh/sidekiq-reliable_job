# frozen_string_literal: true

require "sidekiq/component"

module Sidekiq
  module ReliableJob
    # Background process that polls the staged jobs table and pushes
    # pending jobs to Redis for processing.
    class Enqueuer
      include Sidekiq::Component

      BATCH_SIZE = 1000
      POLL_INTERVAL = 0.1
      ERROR_SLEEP = 1
      LOCK_RETRY_SLEEP = 20

      def initialize(config)
        @done = false
        @config = config
      end

      def start
        @thread = Thread.new(&method(:process))
      end

      def stop
        @done = true
      end

      private

      def process
        until @done
          begin
            jobs_processed = process_batch
            sleep POLL_INTERVAL if jobs_processed.zero?
          rescue WithAdvisoryLock::FailedToAcquireLock
            sleep LOCK_RETRY_SLEEP
          rescue StandardError => e
            logger.error "Error in ReliableJob::Enqueuer: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
            sleep ERROR_SLEEP
          end
        end
      end

      def process_batch
        count = 0

        Outbox.transaction do
          Outbox.with_advisory_lock!("sidekiq_reliable_job", transaction: true, timeout_seconds: 0) do
            jobs = Outbox.pending.order(:id).limit(BATCH_SIZE).pluck(:id, :payload)
            return 0 if jobs.empty?

            ids = jobs.map(&:first)
            Outbox.where(id: ids).update_all(status: Outbox::ENQUEUED, enqueued_at: Time.current)
            bulk_push_to_redis(jobs)
            count = jobs.size
          end
        end

        count
      end

      def bulk_push_to_redis(jobs)
        payloads_by_queue = Hash.new { |h, k| h[k] = [] }

        jobs.each do |(_, payload)|
          queue = payload["queue"] || "default"
          payloads_by_queue[queue] << Sidekiq.dump_json(payload)
        end

        Sidekiq.redis do |conn|
          conn.pipelined do |pipeline|
            payloads_by_queue.each do |queue, serialized_payloads|
              pipeline.lpush("queue:#{queue}", serialized_payloads)
            end
          end
        end
      end
    end
  end
end
