# frozen_string_literal: true

require "English"

module Sidekiq
  module ReliableJob
    # Deletes staged jobs from the Outbox after successful completion.
    class ServerMiddleware
      include Sidekiq::ServerMiddleware

      def call(_job_instance, job_payload, _queue)
        yield
      ensure
        if $ERROR_INFO.nil? && job_payload["reliable_job"]
          delete_staged_job(job_payload["jid"])
        end
      end

      private

      def delete_staged_job(jid)
        Outbox.where(jid: jid).delete_all
      rescue StandardError => e
        Sidekiq.logger.error "Failed to delete reliable job #{jid}: #{e.message}"
      end
    end
  end
end
