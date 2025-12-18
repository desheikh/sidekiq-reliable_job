# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::OutboxProcessor do
  subject(:processor) { described_class.new }

  around do |example|
    Sidekiq::Testing.disable! { example.run }
  end

  before { clear_redis_queues }

  describe "#call" do
    context "when there are no pending jobs" do
      it "returns 0" do
        expect(processor.call).to eq(0)
      end
    end

    context "when there are immediate jobs" do
      let!(:default_job1) { create(:outbox, queue: "default") }
      let!(:default_job2) { create(:outbox, queue: "default") }
      let!(:critical_job) { create(:outbox, queue: "critical") }

      it "returns the number of jobs processed" do
        expect(processor.call).to eq(3)
      end

      it "marks all jobs as enqueued with timestamp" do
        processor.call

        [default_job1, default_job2, critical_job].each do |job|
          job.reload
          expect(job.status).to eq("enqueued")
          expect(job.enqueued_at).to be_present
        end
      end

      it "pushes jobs to correct Redis queues" do
        processor.call

        expect(redis_queue_size("default")).to eq(2)
        expect(redis_queue_size("critical")).to eq(1)
      end

      it "preserves job payload in Redis" do
        processor.call

        raw_job = redis_queue_jobs("critical").first
        parsed = JSON.parse(raw_job)

        expect(parsed).to include("class" => "ExampleJob", "args" => ["test message"])
      end
    end

    context "when there are scheduled jobs" do
      let(:schedule_time) { 1.hour.from_now }
      let!(:scheduled_job1) { create(:outbox, scheduled_at: schedule_time) }
      let!(:scheduled_job2) { create(:outbox, scheduled_at: 2.hours.from_now) }

      it "returns the number of jobs processed" do
        expect(processor.call).to eq(2)
      end

      it "marks jobs as scheduled with timestamp" do
        processor.call

        [scheduled_job1, scheduled_job2].each do |job|
          job.reload
          expect(job.status).to eq("scheduled")
          expect(job.enqueued_at).to be_present
        end
      end

      it "pushes jobs to Redis schedule sorted set" do
        processor.call

        expect(redis_schedule_size).to eq(2)
      end

      it "preserves the scheduled time as score" do
        processor.call

        jobs = redis_schedule_jobs
        scores = jobs.map(&:last)

        expect(scores.first).to be_within(1).of(schedule_time.to_f)
      end
    end

    context "when there are both immediate and scheduled jobs" do
      let!(:immediate_job) { create(:outbox, queue: "default") }
      let!(:scheduled_job) { create(:outbox, scheduled_at: 1.hour.from_now) }

      it "processes both types" do
        expect(processor.call).to eq(2)
      end

      it "pushes immediate job to queue" do
        processor.call

        expect(redis_queue_size("default")).to eq(1)
      end

      it "pushes scheduled job to schedule set" do
        processor.call

        expect(redis_schedule_size).to eq(1)
      end

      it "marks jobs with correct statuses" do
        processor.call

        expect(immediate_job.reload.status).to eq("enqueued")
        expect(scheduled_job.reload.status).to eq("scheduled")
      end
    end
  end
end
