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

            immediate, scheduled = partition_jobs(jobs)

            process_immediate_jobs(immediate)
            process_scheduled_jobs(scheduled)

            jobs.size
          end
        end
      end

      private

      def fetch_pending_jobs
        Outbox.pending.order(:id).limit(BATCH_SIZE).pluck(:id, :payload)
      end

      def partition_jobs(jobs)
        jobs.partition { |_, payload| payload["at"].blank? }
      end

      def process_immediate_jobs(jobs)
        return if jobs.empty?

        mark_as_enqueued(jobs)
        push_to_queues(jobs)
      end

      def process_scheduled_jobs(jobs)
        return if jobs.empty?

        mark_as_scheduled(jobs)
        push_to_schedule(jobs)
      end

      def mark_as_enqueued(jobs)
        ids = jobs.map(&:first)
        Outbox.where(id: ids).update_all(status: Outbox::ENQUEUED, enqueued_at: Time.current)
      end

      def mark_as_scheduled(jobs)
        ids = jobs.map(&:first)
        Outbox.where(id: ids).update_all(status: Outbox::SCHEDULED, enqueued_at: Time.current)
      end

      def push_to_queues(jobs)
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

      def push_to_schedule(jobs)
        Sidekiq.redis do |conn|
          conn.pipelined do |pipeline|
            jobs.each do |(_id, payload)|
              score = payload["at"].to_f
              pipeline.zadd("schedule", score, Sidekiq.dump_json(payload))
            end
          end
        end
      end
    end
  end
end
