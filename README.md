# Sidekiq::ReliableJob

A Sidekiq extension that provides reliable job delivery by staging jobs to the database before pushing to Redis. This ensures jobs are only enqueued when database transactions commit, and provides durability during Redis outages.

## Features

- **Transaction Safety**: Jobs are staged to the database within your transaction. If the transaction rolls back, the job is never enqueued.
- **Redis Outage Resilience**: Jobs continue to be accepted during Redis outages and are pushed once Redis is available.
- **Reliable Delivery**: A background enqueuer process polls staged jobs and pushes them to Redis.
- **Automatic Cleanup**: Jobs are automatically deleted from the staging table after successful completion.
- **ActiveJob Support**: Works with both native Sidekiq jobs and ActiveJob.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "sidekiq-reliable_job"
```

Then execute:

```bash
bundle install
```

## Setup

### 1. Run the generator to create the migration

```bash
rails generate sidekiq_reliable_job:install
```

This creates a migration for the `reliable_job_outbox` table.

### 2. Run the migration

```bash
rails db:migrate
```

### 3. Configure Sidekiq

In your Sidekiq initializer (`config/initializers/sidekiq.rb`):

```ruby
require "sidekiq/reliable_job"

Sidekiq::ReliableJob.configure do |config|
  # The ActiveRecord base class for the Outbox model (default: "ActiveRecord::Base")
  config.base_class = "ApplicationRecord"
  # Enable reliable job for all jobs (default: false)
  config.enable_for_all_jobs = false
  # Preserve dead jobs in outbox with "dead" status instead of deleting (default: false)
  config.preserve_dead_jobs = false
end

Sidekiq.configure_client do |config|
  Sidekiq::ReliableJob.configure_client!(config)
end

Sidekiq.configure_server do |config|
  Sidekiq::ReliableJob.configure_server!(config)
end
```

## Usage

### Option 1: Enable for all jobs (recommended)

When `enable_for_all_jobs` is `true`, all Sidekiq jobs are automatically staged through the outbox. No changes to job classes required.

To opt-out a specific job from staged push:

```ruby
class DirectPushJob
  include Sidekiq::Job
  sidekiq_options reliable_job: false

  def perform
    # This job will push directly to Redis
  end
end
```

### Option 2: Enable per job (opt-in)

If `enable_for_all_jobs` is `false` (default), use `sidekiq_options` to opt-in specific jobs:

```ruby
class MyJob
  include Sidekiq::Job
  sidekiq_options reliable_job: true

  def perform(user_id)
    # Your job logic here
  end
end
```

### ActiveJob Support

ReliableJob works with ActiveJob. Configure the job using `sidekiq_options`:

```ruby
class MyActiveJob < ApplicationJob
  queue_as :default
  sidekiq_options reliable_job: true

  def perform(user_id)
    # Your job logic here
  end
end
```

### Example

When you enqueue the job within a transaction, it will be staged to the database first:

```ruby
ActiveRecord::Base.transaction do
  user = User.create!(name: "Alice")
  MyJob.perform_async(user.id)  # Staged to database, not Redis

  # If an exception is raised here, the job is never enqueued
end
# Transaction committed - job is now pushed to Redis by the enqueuer
```

## How It Works

1. **Client Middleware**: Intercepts `perform_async` and `perform_in` calls and stages jobs to the `reliable_job_outbox` table instead of pushing directly to Redis.
2. **Outbox Processor**: A background thread polls for pending jobs and pushes them to Redis:
3. **Server Middleware**: After successful job completion, deletes the staged job record from the outbox.
4. **Death Handler**: When a job exhausts all retries, removes (or optionally preserves) the record from the outbox.

## Deployment & Rollout

When enabling ReliableJob for the first time, use a **two-phase deployment** to avoid orphaned outbox records:

### Phase 1: Deploy with ReliableJob Disabled

First, deploy the gem with all jobs disabled. This installs the middleware on all containers without affecting any jobs:

```ruby
Sidekiq::ReliableJob.configure do |config|
  config.enable_for_all_jobs = false  # No jobs use reliable delivery yet
end
```

Wait for all containers to be running with the new code.

### Phase 2: Enable ReliableJob

Once all containers have the middleware installed, enable reliable delivery for your jobs:

```ruby
Sidekiq::ReliableJob.configure do |config|
  config.enable_for_all_jobs = true  # Or enable per-job with sidekiq_options
end
```

### Why This Matters

If containers are running different versions during deployment:
- New containers may stage jobs while old containers process them
- Old containers don't have the server middleware, so they won't delete completed jobs from the outbox
- This leaves orphaned "enqueued" records in the database

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `enable_for_all_jobs` | `false` | When `true`, all jobs are staged through the outbox |
| `base_class` | `"ActiveRecord::Base"` | The ActiveRecord base class for the Outbox model |
| `preserve_dead_jobs` | `false` | When `true`, keeps dead jobs in outbox with "dead" status instead of deleting |

## Limitations

### Batch Jobs (Sidekiq Pro/Enterprise)

Jobs that are part of a batch (have a `bid` in their payload) are **automatically bypassed** and pushed directly to Redis. This ensures batch callbacks and completion tracking work correctly.

### Internal Sidekiq Jobs

All internal Sidekiq jobs (classes starting with `Sidekiq::`) are **automatically bypassed**. This includes:

- Batch callbacks (`Sidekiq::Batch::Callback`)
- Batch empty handlers (`Sidekiq::Batch::Empty`)
- Enterprise periodic jobs (`Sidekiq::Periodic::*`)
- Any other internal Sidekiq system jobs

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wealthsimple/sidekiq-reliable_job.
