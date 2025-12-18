# frozen_string_literal: true

module Sidekiq
  module ReliableJob
    # Configuration options for ReliableJob.
    class Configuration
      attr_accessor :base_class, :enable_for_all_jobs, :preserve_dead_jobs

      def initialize
        @base_class = "ActiveRecord::Base"
        @enable_for_all_jobs = false
        @preserve_dead_jobs = false
      end
    end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end
    end
  end
end
