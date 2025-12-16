# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module SidekiqReliableJob
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates the migration for the reliable_job_outbox table"

      def create_migration_file
        migration_template(
          "migration.rb.tt",
          "db/migrate/create_reliable_job_outbox.rb",
        )
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
