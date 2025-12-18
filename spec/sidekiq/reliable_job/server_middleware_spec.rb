# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::ServerMiddleware do
  subject(:middleware) { described_class.new }

  let(:job_instance) { ExampleJob.new }
  let(:queue) { "default" }

  describe "#call" do
    context "when job has reliable_job flag" do
      let!(:outbox_record) { create(:outbox, jid: "abc123") }
      let(:job_payload) { { "jid" => "abc123", "reliable_job" => true } }

      it "deletes the staged job after successful completion" do
        expect {
          middleware.call(job_instance, job_payload, queue) { true }
        }.to change(Sidekiq::ReliableJob::Outbox, :count).by(-1)
      end

      context "when job raises an exception" do
        it "does not delete the staged job" do
          expect do
            middleware.call(job_instance, job_payload, queue) { raise "boom" }
          rescue StandardError
            nil
          end.not_to change(Sidekiq::ReliableJob::Outbox, :count)
        end

        it "re-raises the original exception" do
          expect {
            middleware.call(job_instance, job_payload, queue) { raise "original error" }
          }.to raise_error("original error")
        end
      end
    end

    context "when job does not have reliable_job flag" do
      let!(:outbox_record) { create(:outbox, jid: "abc123") }
      let(:job_payload) { { "jid" => "abc123" } }

      it "does not delete any staged jobs" do
        expect {
          middleware.call(job_instance, job_payload, queue) { true }
        }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
      end
    end

    context "when delete fails" do
      let(:job_payload) { { "jid" => "nonexistent", "reliable_job" => true } }

      before do
        allow(Sidekiq::ReliableJob::Outbox).to receive(:where).and_raise(StandardError.new("DB error"))
        allow(Sidekiq.logger).to receive(:error)
      end

      it "logs error but does not fail the job" do
        expect {
          middleware.call(job_instance, job_payload, queue) { true }
        }.not_to raise_error

        expect(Sidekiq.logger).to have_received(:error).with(/Failed to delete reliable job/)
      end
    end
  end
end
