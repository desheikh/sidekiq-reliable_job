# frozen_string_literal: true

require "securerandom"

module Sidekiq
  module ReliableJob
    # Stages jobs to the Outbox for later delivery to Redis.
    class Client
      class << self
        def push(item)
          item["jid"] ||= SecureRandom.hex(12)

          Outbox.create!(
            jid: item["jid"],
            job_class: extract_job_class(item),
            payload: item,
            status: Outbox::PENDING,
          )

          item["jid"]
        end

        private

        def extract_job_class(item)
          (item["wrapped"] || item["class"]).to_s
        end
      end
    end
  end
end
