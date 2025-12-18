# frozen_string_literal: true

module Sidekiq
  module ReliableJob
    # Intercepts job pushes and stages them to the Outbox instead of Redis.
    class ClientMiddleware
      def call(_job_class, job, _queue, _redis_pool)
        return yield if skip_staging?(job)

        job["reliable_job"] = true
        Client.push(job)

        yield if testing_enabled?
      end

      private

      def skip_staging?(job)
        retry?(job) || batch?(job) || sidekiq_internal?(job) || !enabled_for?(job)
      end

      def batch?(job)
        job.key?("bid")
      end

      # Bypass internal Sidekiq jobs (batch callbacks, Enterprise features, etc.)
      # but not ActiveJob wrapper which should be staged
      def sidekiq_internal?(job)
        klass = job["class"].to_s
        klass.start_with?("Sidekiq::") && klass != "Sidekiq::ActiveJob::Wrapper"
      end

      def enabled_for?(job)
        option = reliable_job_option(job)

        case option
        when true then true
        when false then false
        else ReliableJob.configuration.enable_for_all_jobs
        end
      end

      def reliable_job_option(job)
        return job["reliable_job"] if job.key?("reliable_job")

        wrapped_class_option(job)
      end

      def wrapped_class_option(job)
        wrapped = job["wrapped"]
        return unless wrapped

        klass = wrapped.is_a?(Class) ? wrapped : wrapped.to_s.safe_constantize
        klass&.sidekiq_options_hash&.dig("reliable_job")
      end

      def retry?(job)
        job.key?("retry_count")
      end

      def testing_enabled?
        defined?(Sidekiq::Testing) && Sidekiq::Testing.enabled?
      end
    end
  end
end
