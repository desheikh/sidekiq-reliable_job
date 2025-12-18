# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::ClientMiddleware do
  subject(:call) { middleware.call(job_class, job, queue, nil) { true } }

  let(:middleware) { described_class.new }
  let(:job_class) { "TestJob" }
  let(:job) { { "class" => job_class, "args" => [1, 2], "jid" => "abc123" } }
  let(:queue) { "default" }
  let(:yielded) { false }

  around do |example|
    Sidekiq::Testing.disable! { example.run }
  end

  shared_examples "stages the job" do
    it "stages the job to the outbox" do
      call
      expect(Sidekiq::ReliableJob::Outbox.count).to eq(1)
    end

    it "does not yield to the next middleware" do
      expect { middleware.call(job_class, job, queue, nil) { raise "should not yield" } }.not_to raise_error
    end
  end

  shared_examples "bypasses staging" do
    it "does not stage the job" do
      call
      expect(Sidekiq::ReliableJob::Outbox.count).to eq(0)
    end

    it "yields to the next middleware" do
      yielded = false
      middleware.call(job_class, job, queue, nil) { yielded = true }
      expect(yielded).to be true
    end
  end

  describe "#call" do
    context "when enable_for_all_jobs is false (default)" do
      before { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false }

      include_examples "bypasses staging"

      context "when job opts in with reliable_job: true" do
        let(:job) { super().merge("reliable_job" => true) }

        include_examples "stages the job"
      end
    end

    context "when enable_for_all_jobs is true" do
      before { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = true }
      after { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false }

      include_examples "stages the job"

      it "marks the job as reliable_job" do
        call
        expect(job["reliable_job"]).to be true
      end

      context "when job opts out with reliable_job: false" do
        let(:job) { super().merge("reliable_job" => false) }

        include_examples "bypasses staging"
      end
    end

    context "with ActiveJob wrapper" do
      let(:job_class) { "Sidekiq::ActiveJob::Wrapper" }

      context "when wrapped class has reliable_job: true" do
        let(:job) do
          {
            "class" => job_class,
            "wrapped" => ExampleActiveJob,
            "args" => [{ "job_class" => "ExampleActiveJob" }],
            "jid" => "abc123",
          }
        end

        include_examples "stages the job"
      end

      context "when wrapped class is a string" do
        let(:job) do
          {
            "class" => job_class,
            "wrapped" => "ExampleActiveJob",
            "args" => [{ "job_class" => "ExampleActiveJob" }],
            "jid" => "abc123",
          }
        end

        include_examples "stages the job"
      end

      context "when wrapped class does not have reliable_job option" do
        let(:job) do
          {
            "class" => job_class,
            "wrapped" => RegularActiveJob,
            "args" => [{ "job_class" => "RegularActiveJob" }],
            "jid" => "abc123",
          }
        end

        include_examples "bypasses staging"
      end
    end

    context "when job is a retry" do
      before { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = true }
      after { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false }

      let(:job) do
        {
          "class" => job_class,
          "args" => [1, 2],
          "jid" => "abc123",
          "reliable_job" => true,
          "retry_count" => 0,
        }
      end

      include_examples "bypasses staging"
    end

    context "when job is scheduled" do
      before { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = true }
      after { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false }

      let(:job) do
        {
          "class" => job_class,
          "args" => [1, 2],
          "jid" => "scheduled123",
          "at" => 1.hour.from_now.to_f,
        }
      end

      include_examples "stages the job"

      it "preserves the scheduled time in payload" do
        call
        outbox = Sidekiq::ReliableJob::Outbox.last
        expect(outbox.payload["at"]).to be_present
      end
    end

    context "when job is part of a batch" do
      before { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = true }
      after { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false }

      let(:job) do
        {
          "class" => job_class,
          "args" => [1, 2],
          "jid" => "batch123",
          "bid" => "abc123def456",
        }
      end

      include_examples "bypasses staging"
    end

    context "when job is a Sidekiq internal job" do
      before { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = true }
      after { Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false }

      context "with batch callback" do
        let(:job) do
          {
            "class" => "Sidekiq::Batch::Callback",
            "args" => %w[success batch123 default],
            "jid" => "callback123",
          }
        end

        include_examples "bypasses staging"
      end

      context "with other Sidekiq internal class" do
        let(:job) do
          {
            "class" => "Sidekiq::Periodic::Loop",
            "args" => [],
            "jid" => "internal123",
          }
        end

        include_examples "bypasses staging"
      end
    end
  end
end
