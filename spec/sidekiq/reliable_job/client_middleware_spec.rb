# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sidekiq::ReliableJob::ClientMiddleware do
  let(:middleware) { described_class.new }
  let(:job_class) { "TestJob" }
  let(:job) { { "class" => job_class, "args" => [1, 2], "jid" => "abc123" } }
  let(:queue) { "default" }
  let(:redis_pool) { nil }

  describe "#call" do
    context "when enable_for_all_jobs is false" do
      before do
        Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false
      end

      it "yields to the next middleware" do
        yielded = false
        middleware.call(job_class, job, queue, redis_pool) { yielded = true }
        expect(yielded).to be true
      end

      it "does not stage the job" do
        middleware.call(job_class, job, queue, redis_pool) { true }
        expect(Sidekiq::ReliableJob::Outbox.count).to eq(0)
      end
    end

    context "when enable_for_all_jobs is true" do
      before do
        Sidekiq::ReliableJob.configuration.enable_for_all_jobs = true
      end

      after do
        Sidekiq::ReliableJob.configuration.enable_for_all_jobs = false
      end

      it "does not yield to the next middleware" do
        yielded = false
        middleware.call(job_class, job, queue, redis_pool) { yielded = true }
        expect(yielded).to be false
      end

      it "stages the job to the outbox" do
        middleware.call(job_class, job, queue, redis_pool) { true }
        expect(Sidekiq::ReliableJob::Outbox.count).to eq(1)
      end

      it "marks the job as reliable_job" do
        middleware.call(job_class, job, queue, redis_pool) { true }
        expect(job["reliable_job"]).to be true
      end

      it "returns false to prevent normal Redis push" do
        result = middleware.call(job_class, job, queue, redis_pool) { true }
        expect(result).to be false
      end

      context "when job explicitly opts out with reliable_job: false" do
        let(:job) { { "class" => job_class, "args" => [1, 2], "jid" => "abc123", "reliable_job" => false } }

        it "yields to the next middleware" do
          yielded = false
          middleware.call(job_class, job, queue, redis_pool) { yielded = true }
          expect(yielded).to be true
        end

        it "does not stage the job" do
          middleware.call(job_class, job, queue, redis_pool) { true }
          expect(Sidekiq::ReliableJob::Outbox.count).to eq(0)
        end
      end

      context "when job already has reliable_job: true (via JobExtension)" do
        let(:job) { { "class" => job_class, "args" => [1, 2], "jid" => "abc123", "reliable_job" => true } }

        it "yields to the next middleware to avoid double staging" do
          yielded = false
          middleware.call(job_class, job, queue, redis_pool) { yielded = true }
          expect(yielded).to be true
        end

        it "does not stage the job again" do
          middleware.call(job_class, job, queue, redis_pool) { true }
          expect(Sidekiq::ReliableJob::Outbox.count).to eq(0)
        end
      end
    end
  end
end
