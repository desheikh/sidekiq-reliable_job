# frozen_string_literal: true

require "securerandom"
require "sidekiq/client"

module Sidekiq
  module ReliableJob
    # A Sidekiq client that stages jobs to the database instead of pushing
    # directly to Redis. Jobs are later pushed by the Enqueuer.
    class Client
      def initialize(pool: nil, config: nil)
        @redis_client = Sidekiq::Client.new(pool: pool, config: config)
      end

      def push(item)
        # In Sidekiq test modes, delegate to the normal client
        return @redis_client.push(item) if sidekiq_testing_enabled?

        item["jid"] ||= SecureRandom.hex(12)

        Outbox.create!({
          jid: item["jid"],
          job_class: extract_job_class(item),
          payload: item,
          status: Outbox::PENDING,
        })

        item["jid"]
      end

      delegate :push_bulk, to: :@redis_client

      private

      # For ActiveJob, the actual job class is stored in "wrapped"
      # For native Sidekiq jobs, it's in "class"
      def extract_job_class(item)
        (item["wrapped"] || item["class"]).to_s
      end

      def sidekiq_testing_enabled?
        defined?(Sidekiq::Testing) && Sidekiq::Testing.enabled?
      end
    end
  end
end
