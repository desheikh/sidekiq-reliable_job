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

      it "does not delete the staged job if an exception is raised" do
        expect {
          begin
            middleware.call(job_instance, job_payload, queue) { raise "boom" }
          rescue StandardError
            nil
          end
        }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
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
  end
end
