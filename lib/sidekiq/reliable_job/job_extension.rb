# frozen_string_literal: true

module Sidekiq
  module ReliableJob
    # Include this module in your Sidekiq job class to enable reliable
    # enqueuing. Jobs will be staged to the database and only pushed to Redis
    # after the database transaction commits.
    #
    # Example:
    #   class MyJob
    #     include Sidekiq::Job
    #     include Sidekiq::ReliableJob::JobExtension
    #
    #     def perform(user_id)
    #       # ...
    #     end
    #   end
    #
    module JobExtension
      def self.included(base)
        base.extend(ClassMethods)
        base.sidekiq_options(
          "client_class" => Sidekiq::ReliableJob::Client,
          "reliable_job" => true,
        )
      end

      module ClassMethods
        # Override to add reliable_job flag to the payload
        def client_push(item)
          item["reliable_job"] = true
          super
        end
      end
    end
  end
end

# Register the transient attribute so it doesn't get persisted in Redis
Sidekiq::JobUtil::TRANSIENT_ATTRIBUTES << "client_class"
