# frozen_string_literal: true

require_relative "lib/sidekiq/reliable_job/version"

Gem::Specification.new do |spec|
  spec.name = "sidekiq-reliable_job"
  spec.version = Sidekiq::ReliableJob::VERSION
  spec.authors = ["Zulfiqar Ali"]
  spec.email = ["zulfiqar@wealthsimple.com"]

  spec.summary = "Reliable enqueuing and completion tracking for Sidekiq jobs"
  spec.description = "A Sidekiq extension that ensures jobs are only enqueued when database transactions commit, " \
                     "jobs are deleted when they are completed."
  spec.homepage = "https://github.com/wealthsimple/sidekiq-reliable_job"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/wealthsimple/sidekiq-reliable_job"
  spec.metadata["changelog_uri"] = "https://github.com/wealthsimple/sidekiq-reliable_job/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.1"
  spec.add_dependency "sidekiq", ">= 7.0"
  spec.add_dependency "with_advisory_lock", ">= 5.0"
end
