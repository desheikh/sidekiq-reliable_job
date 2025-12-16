# frozen_string_literal: true

require "sidekiq"
require "sidekiq/job"
require "with_advisory_lock"

require_relative "reliable_job/version"
require_relative "reliable_job/configuration"
require_relative "reliable_job/outbox"
require_relative "reliable_job/client"
require_relative "reliable_job/client_middleware"
require_relative "reliable_job/server_middleware"
require_relative "reliable_job/enqueuer"
require_relative "reliable_job/job_extension"

module Sidekiq
  module ReliableJob
    class Error < StandardError; end

    class << self
      def configure_client!(config)
        config.client_middleware do |chain|
          chain.add Sidekiq::ReliableJob::ClientMiddleware
        end
      end

      def configure_server!(config)
        configure_client!(config)

        config.server_middleware do |chain|
          chain.add Sidekiq::ReliableJob::ServerMiddleware
        end

        config.death_handlers << method(:on_death)

        enqueuer = Enqueuer.new(config)

        config.on(:startup) do
          enqueuer.start
        end

        config.on(:quiet) do
          enqueuer.stop
        end
      end

      def on_death(job, _exception)
        return unless job["reliable_job"]

        Outbox.where(jid: job["jid"]).update_all(status: Outbox::DEAD)
      end
    end
  end
end
