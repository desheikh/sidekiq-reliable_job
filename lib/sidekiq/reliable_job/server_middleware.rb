# frozen_string_literal: true

require "English"

module Sidekiq
  module ReliableJob
    # Server middleware that deletes jobs from the staging table
    # when they complete successfully.
    class ServerMiddleware
      include Sidekiq::ServerMiddleware

      def call(_job_instance, job_payload, _queue)
        yield
      ensure
        # Only delete if the job completed successfully (no exception raised)
        # and it was a reliable job
        if $ERROR_INFO.nil? && job_payload["reliable_job"]
          delete_staged_job(job_payload["jid"])
        end
      end

      private

      def delete_staged_job(jid)
        Outbox.where(jid: jid).delete_all
      rescue StandardError => e
        # Log but don't fail the job if we can't delete the record
        Sidekiq.logger.error "Failed to delete reliable job #{jid}: #{e.message}"
      end
    end
  end
end
