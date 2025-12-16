# frozen_string_literal: true

module Sidekiq
  module ReliableJob
    # Client middleware that intercepts all job pushes and routes them through
    # the Outbox when enable_for_all_jobs is configured.
    class ClientMiddleware
      def call(_job_class, job, _queue, _redis_pool)
        return yield unless Sidekiq::ReliableJob.configuration.enable_for_all_jobs

        # Skip if job already has reliable_job set (either by JobExtension or opt-out)
        return yield if job.key?("reliable_job")

        job["reliable_job"] = true
        Client.new.push(job)

        false
      end
    end
  end
end
