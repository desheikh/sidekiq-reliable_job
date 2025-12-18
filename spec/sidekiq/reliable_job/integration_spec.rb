# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass
RSpec.describe "ReliableJob Integration" do
  # Disable fake mode for these tests since we're testing the full flow
  around do |example|
    Sidekiq::Testing.disable! do
      example.run
    end
  end

  before do
    Sidekiq.redis do |conn|
      keys = conn.keys("queue:*")
      conn.del(*keys) if keys.any?
    end
  end

  describe "full job lifecycle" do
    it "stages job to database, enqueues to Redis, and deletes after processing" do
      # Step 1: Enqueue a job using the reliable job option
      ExampleJob.perform_async("integration test")

      # Verify job is staged in database (get the record by most recent)
      outbox_record = Sidekiq::ReliableJob::Outbox.order(:id).last
      expect(outbox_record).to be_present
      expect(outbox_record.status).to eq("pending")
      expect(outbox_record.job_class).to eq("ExampleJob")

      jid = outbox_record.jid

      # Verify job is NOT in Redis yet (because enqueuer hasn't run)
      Sidekiq.redis do |conn|
        expect(conn.llen("queue:default")).to eq(0)
      end

      # Step 2: Run the enqueuer to push jobs to Redis
      config = Sidekiq.default_configuration
      enqueuer = Sidekiq::ReliableJob::Enqueuer.new(config)
      enqueuer.send(:process_batch)

      # Verify job is now in Redis
      Sidekiq.redis do |conn|
        expect(conn.llen("queue:default")).to eq(1)
      end

      # Verify job status is updated in database
      outbox_record.reload
      expect(outbox_record.status).to eq("enqueued")
      expect(outbox_record.enqueued_at).to be_present

      # Step 3: Simulate job completion via server middleware
      middleware = Sidekiq::ReliableJob::ServerMiddleware.new
      job_payload = outbox_record.payload.merge("reliable_job" => true)

      middleware.call(ExampleJob.new, job_payload, "default") { true }

      # Verify job is deleted from database after successful completion
      expect(Sidekiq::ReliableJob::Outbox.exists?(jid: jid)).to be false
    end

    it "does not lose jobs when transaction rolls back" do
      # Job creation inside a rolled-back transaction should not persist
      expect {
        ActiveRecord::Base.transaction do
          ExampleJob.perform_async("this will be rolled back")
          raise ActiveRecord::Rollback
        end
      }.not_to change(Sidekiq::ReliableJob::Outbox, :count)

      # And nothing should be in Redis
      Sidekiq.redis do |conn|
        expect(conn.llen("queue:default")).to eq(0)
      end
    end

    it "keeps job in database when processing fails" do
      ExampleJob.perform_async("will fail")
      outbox_record = Sidekiq::ReliableJob::Outbox.order(:id).last
      jid = outbox_record.jid

      # Run enqueuer
      config = Sidekiq.default_configuration
      enqueuer = Sidekiq::ReliableJob::Enqueuer.new(config)
      enqueuer.send(:process_batch)

      # Simulate job failure via server middleware
      middleware = Sidekiq::ReliableJob::ServerMiddleware.new
      job_payload = outbox_record.payload.merge("reliable_job" => true)

      expect {
        middleware.call(ExampleJob.new, job_payload, "default") { raise "Job failed!" }
      }.to raise_error("Job failed!")

      # Job should still be in database (for retry handling)
      expect(Sidekiq::ReliableJob::Outbox.exists?(jid: jid)).to be true
    end

    it "deletes job from outbox when retries exhausted" do
      ExampleJob.perform_async("will die")
      outbox_record = Sidekiq::ReliableJob::Outbox.order(:id).last
      jid = outbox_record.jid

      # Run enqueuer
      config = Sidekiq.default_configuration
      enqueuer = Sidekiq::ReliableJob::Enqueuer.new(config)
      enqueuer.send(:process_batch)

      job_payload = outbox_record.payload.merge("reliable_job" => true)

      # Simulate job death (retries exhausted)
      Sidekiq::ReliableJob.on_death(job_payload, RuntimeError.new("exhausted"))

      # Job should be deleted from outbox
      expect(Sidekiq::ReliableJob::Outbox.exists?(jid: jid)).to be false
    end
  end

  describe "regular jobs without ReliableJob extension" do
    it "bypasses the staging mechanism" do
      expect {
        RegularJob.perform_async("regular job")
      }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
    end
  end

  describe "ActiveJob integration" do
    it "stages ActiveJob jobs with reliable_job: true" do
      # Enqueue an ActiveJob with reliable_job option
      ExampleActiveJob.perform_later("activejob test")

      # Verify job is staged in database
      outbox_record = Sidekiq::ReliableJob::Outbox.order(:id).last
      expect(outbox_record).to be_present
      expect(outbox_record.status).to eq("pending")
      expect(outbox_record.job_class).to eq("ExampleActiveJob")

      # Verify job is NOT in Redis yet
      Sidekiq.redis do |conn|
        expect(conn.llen("queue:default")).to eq(0)
      end

      # Run the enqueuer to push jobs to Redis
      config = Sidekiq.default_configuration
      enqueuer = Sidekiq::ReliableJob::Enqueuer.new(config)
      enqueuer.send(:process_batch)

      # Verify job is now in Redis
      Sidekiq.redis do |conn|
        expect(conn.llen("queue:default")).to eq(1)
      end

      # Verify job status is updated in database
      outbox_record.reload
      expect(outbox_record.status).to eq("enqueued")
    end

    it "bypasses staging for ActiveJob jobs without reliable_job option" do
      expect {
        RegularActiveJob.perform_later("regular activejob")
      }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
    end

    it "does not lose ActiveJob jobs when transaction rolls back" do
      # Job creation inside a rolled-back transaction should not persist
      expect {
        ActiveRecord::Base.transaction do
          ExampleActiveJob.perform_later("this will be rolled back")
          raise ActiveRecord::Rollback
        end
      }.not_to change(Sidekiq::ReliableJob::Outbox, :count)

      # And nothing should be in Redis
      Sidekiq.redis do |conn|
        expect(conn.llen("queue:default")).to eq(0)
      end
    end

    it "full lifecycle: stages, enqueues, and deletes ActiveJob after processing" do
      ExampleActiveJob.perform_later("full lifecycle test")

      outbox_record = Sidekiq::ReliableJob::Outbox.order(:id).last
      jid = outbox_record.jid

      # Run enqueuer
      config = Sidekiq.default_configuration
      enqueuer = Sidekiq::ReliableJob::Enqueuer.new(config)
      enqueuer.send(:process_batch)

      # Simulate job completion via server middleware
      middleware = Sidekiq::ReliableJob::ServerMiddleware.new
      job_payload = outbox_record.reload.payload.merge("reliable_job" => true)

      # For ActiveJob, the worker is the JobWrapper
      wrapper = ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper.new
      middleware.call(wrapper, job_payload, "default") { true }

      # Verify job is deleted from database after successful completion
      expect(Sidekiq::ReliableJob::Outbox.exists?(jid: jid)).to be false
    end
  end
end
# rubocop:enable RSpec/DescribeClass
