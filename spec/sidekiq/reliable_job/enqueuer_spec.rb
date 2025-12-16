# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::Enqueuer do
  subject(:enqueuer) { described_class.new(config) }

  let(:config) { instance_double(Sidekiq::Config) }

  # Disable fake mode for these tests since we're testing real Redis interactions
  around do |example|
    Sidekiq::Testing.disable! do
      example.run
    end
  end

  # Clean up Redis before each test
  before do
    Sidekiq.redis do |conn|
      keys = conn.keys("queue:*")
      conn.del(*keys) if keys.any?
    end
  end

  describe "#start and #stop" do
    it "starts a background thread" do
      # Start the enqueuer and immediately stop it to prevent infinite loop
      enqueuer.start
      enqueuer.stop
      sleep 0.1 # Allow thread to start
      expect(enqueuer.instance_variable_get(:@thread)).to be_a(Thread)
    end

    it "stops the processing loop" do
      enqueuer.stop
      expect(enqueuer.instance_variable_get(:@done)).to be true
    end
  end

  describe "#process_batch" do
    context "when there are no pending jobs" do
      it "returns 0" do
        expect(enqueuer.send(:process_batch)).to eq(0)
      end
    end

    context "when there are pending jobs" do
      let!(:job1) { create(:outbox, queue: "default") }
      let!(:job2) { create(:outbox, queue: "default") }
      let!(:job3) { create(:outbox, queue: "critical") }

      it "returns the number of jobs processed" do
        expect(enqueuer.send(:process_batch)).to eq(3)
      end

      it "marks jobs as enqueued" do
        enqueuer.send(:process_batch)

        [job1, job2, job3].each do |job|
          expect(job.reload.status).to eq("enqueued")
          expect(job.reload.enqueued_at).to be_present
        end
      end

      it "pushes jobs to Redis queues" do
        enqueuer.send(:process_batch)

        Sidekiq.redis do |conn|
          default_jobs = conn.lrange("queue:default", 0, -1)
          critical_jobs = conn.lrange("queue:critical", 0, -1)

          expect(default_jobs.size).to eq(2)
          expect(critical_jobs.size).to eq(1)
        end
      end

      it "preserves job payload in Redis" do
        enqueuer.send(:process_batch)

        Sidekiq.redis do |conn|
          raw_job = conn.lrange("queue:critical", 0, 0).first
          parsed_job = JSON.parse(raw_job)

          expect(parsed_job["class"]).to eq("ExampleJob")
          expect(parsed_job["args"]).to eq(["test message"])
        end
      end
    end
  end

  describe "#bulk_push_to_redis" do
    let!(:job1) { create(:outbox, queue: "default") }
    let!(:job2) { create(:outbox, queue: "high") }

    it "groups jobs by queue and pushes to correct Redis queues" do
      # bulk_push_to_redis expects [id, payload] tuples from pluck
      jobs = [[job1.id, job1.payload], [job2.id, job2.payload]]

      enqueuer.send(:bulk_push_to_redis, jobs)

      Sidekiq.redis do |conn|
        expect(conn.llen("queue:default")).to eq(1)
        expect(conn.llen("queue:high")).to eq(1)
      end
    end
  end
end
