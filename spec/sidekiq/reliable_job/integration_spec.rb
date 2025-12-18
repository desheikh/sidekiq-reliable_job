# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass
RSpec.describe "ReliableJob Integration" do
  let(:processor) { Sidekiq::ReliableJob::OutboxProcessor.new }
  let(:server_middleware) { Sidekiq::ReliableJob::ServerMiddleware.new }

  around do |example|
    Sidekiq::Testing.disable! { example.run }
  end

  before { clear_redis_queues }

  describe "full job lifecycle" do
    it "stages, enqueues, processes, and deletes job" do
      # Stage
      ExampleJob.perform_async("test")
      outbox = Sidekiq::ReliableJob::Outbox.last

      expect(outbox).to have_attributes(status: "pending", job_class: "ExampleJob")
      expect(redis_queue_size("default")).to eq(0)

      # Enqueue
      processor.call

      expect(outbox.reload).to have_attributes(status: "enqueued", enqueued_at: be_present)
      expect(redis_queue_size("default")).to eq(1)

      # Process
      job_payload = outbox.payload.merge("reliable_job" => true)
      server_middleware.call(ExampleJob.new, job_payload, "default") { true }

      expect(Sidekiq::ReliableJob::Outbox.exists?(jid: outbox.jid)).to be false
    end

    it "preserves job on failure for retry" do
      ExampleJob.perform_async("will fail")
      outbox = Sidekiq::ReliableJob::Outbox.last

      processor.call

      job_payload = outbox.payload.merge("reliable_job" => true)

      expect {
        server_middleware.call(ExampleJob.new, job_payload, "default") { raise "failed" }
      }.to raise_error("failed")

      expect(Sidekiq::ReliableJob::Outbox.exists?(jid: outbox.jid)).to be true
    end

    it "deletes job when retries exhausted" do
      ExampleJob.perform_async("will die")
      outbox = Sidekiq::ReliableJob::Outbox.last

      processor.call

      job_payload = outbox.payload.merge("reliable_job" => true)
      Sidekiq::ReliableJob.on_death(job_payload, RuntimeError.new("exhausted"))

      expect(Sidekiq::ReliableJob::Outbox.exists?(jid: outbox.jid)).to be false
    end

    it "rolls back job on transaction rollback" do
      expect {
        ActiveRecord::Base.transaction do
          ExampleJob.perform_async("rollback")
          raise ActiveRecord::Rollback
        end
      }.not_to change(Sidekiq::ReliableJob::Outbox, :count)

      expect(redis_queue_size("default")).to eq(0)
    end
  end

  describe "opt-in/opt-out" do
    it "bypasses staging for jobs without reliable_job option" do
      expect { RegularJob.perform_async("test") }.
        not_to change(Sidekiq::ReliableJob::Outbox, :count)
    end
  end

  describe "ActiveJob integration" do
    it "stages and processes ActiveJob with reliable_job: true" do
      ExampleActiveJob.perform_later("test")
      outbox = Sidekiq::ReliableJob::Outbox.last

      expect(outbox).to have_attributes(status: "pending", job_class: "ExampleActiveJob")

      processor.call

      expect(outbox.reload.status).to eq("enqueued")
      expect(redis_queue_size("default")).to eq(1)
    end

    it "bypasses staging for ActiveJob without reliable_job option" do
      expect { RegularActiveJob.perform_later("test") }.
        not_to change(Sidekiq::ReliableJob::Outbox, :count)
    end

    it "rolls back ActiveJob on transaction rollback" do
      expect {
        ActiveRecord::Base.transaction do
          ExampleActiveJob.perform_later("rollback")
          raise ActiveRecord::Rollback
        end
      }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
    end

    it "completes full lifecycle for ActiveJob" do
      ExampleActiveJob.perform_later("lifecycle test")
      outbox = Sidekiq::ReliableJob::Outbox.last

      processor.call

      job_payload = outbox.reload.payload.merge("reliable_job" => true)
      wrapper = ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper.new
      server_middleware.call(wrapper, job_payload, "default") { true }

      expect(Sidekiq::ReliableJob::Outbox.exists?(jid: outbox.jid)).to be false
    end
  end
end
# rubocop:enable RSpec/DescribeClass
