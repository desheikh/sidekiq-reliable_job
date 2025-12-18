# frozen_string_literal: true

module Sidekiq
  module ReliableJob
    # Fetches pending jobs from the Outbox and pushes them to Redis.
    class OutboxProcessor
      BATCH_SIZE = 1000

      def call
        Outbox.transaction do
          Outbox.with_advisory_lock!("sidekiq_reliable_job", transaction: true, timeout_seconds: 0) do
            jobs = fetch_pending_jobs
            return 0 if jobs.empty?

            mark_as_enqueued(jobs)
            push_to_redis(jobs)

            jobs.size
          end
        end
      end

      private

      def fetch_pending_jobs
        Outbox.pending.order(:id).limit(BATCH_SIZE).pluck(:id, :payload)
      end

      def mark_as_enqueued(jobs)
        ids = jobs.map(&:first)
        Outbox.where(id: ids).update_all(status: Outbox::ENQUEUED, enqueued_at: Time.current)
      end

      def push_to_redis(jobs)
        jobs_by_queue = jobs.group_by { |_, payload| payload["queue"] || "default" }

        Sidekiq.redis do |conn|
          conn.pipelined do |pipeline|
            jobs_by_queue.each do |queue, queue_jobs|
              payloads = queue_jobs.map { |_, payload| Sidekiq.dump_json(payload) }
              pipeline.lpush("queue:#{queue}", payloads)
            end
          end
        end
      end
    end
  end
end
