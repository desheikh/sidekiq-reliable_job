# frozen_string_literal: true

module Sidekiq
  module ReliableJob
    # Client middleware that intercepts all job pushes and routes them through
    # the Outbox based on configuration and per-job options.
    #
    # Behavior:
    # - If sidekiq_options reliable_job: false -> skip staging (explicit opt-out)
    # - If sidekiq_options reliable_job: true -> stage the job (explicit opt-in)
    # - If reliable_job not set -> use enable_for_all_jobs config (global default)
    class ClientMiddleware
      def call(_job_class, job, _queue, _redis_pool)
        return yield if sidekiq_testing_enabled?
        return yield unless should_stage?(job)

        job["reliable_job"] = true

        # Stage the job to the outbox
        # Client#push sets job["jid"] if not already set
        Client.new.push(job)

        # Return nil to prevent normal Redis push
        # Sidekiq will return job["jid"] to the caller
        nil
      end

      private

      def should_stage?(job)
        # Explicit opt-out
        return false if job["reliable_job"] == false

        # Explicit opt-in or global default
        job["reliable_job"] == true || Sidekiq::ReliableJob.configuration.enable_for_all_jobs
      end

      def sidekiq_testing_enabled?
        defined?(Sidekiq::Testing) && Sidekiq::Testing.enabled?
      end
    end
  end
end
