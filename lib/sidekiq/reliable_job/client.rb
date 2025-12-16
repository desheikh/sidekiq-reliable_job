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
        item["jid"] ||= SecureRandom.hex(12)

        Outbox.create!({
          jid: item["jid"],
          job_class: item["class"].to_s,
          payload: item,
          status: Outbox::PENDING,
        })

        item["jid"]
      end

      delegate :push_bulk, to: :@redis_client
    end
  end
end
