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
    #
    # ActiveJob Support:
    # - For ActiveJob, the actual job class is in job["wrapped"]
    # - sidekiq_options from ActiveJob classes are checked via the wrapped class
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
        option = reliable_job_option(job)

        return false if option == false # Explicit opt-out

        option == true || Sidekiq::ReliableJob.configuration.enable_for_all_jobs
      end

      # Get the reliable_job option from job payload or wrapped class's sidekiq_options
      def reliable_job_option(job)
        return job["reliable_job"] if job.key?("reliable_job")

        # For ActiveJob, check the wrapped class's sidekiq_options
        wrapped = job["wrapped"]
        return nil unless wrapped

        job_class = wrapped.is_a?(Class) ? wrapped : wrapped.to_s.safe_constantize
        job_class&.try(:sidekiq_options_hash)&.dig("reliable_job")
      end

      def sidekiq_testing_enabled?
        defined?(Sidekiq::Testing) && Sidekiq::Testing.enabled?
      end
    end
  end
end
