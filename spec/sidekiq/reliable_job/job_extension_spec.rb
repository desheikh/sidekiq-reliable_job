# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::JobExtension do
  describe "when included in a job class" do
    it "sets the client_class option" do
      expect(ExampleJob.get_sidekiq_options["client_class"]).to eq(Sidekiq::ReliableJob::Client)
    end

    it "sets the reliable_job flag" do
      expect(ExampleJob.get_sidekiq_options["reliable_job"]).to be true
    end
  end

  describe ".perform_async" do
    it "stages the job to the database instead of Redis" do
      expect {
        ExampleJob.perform_async("hello")
      }.to change(Sidekiq::ReliableJob::Outbox, :count).by(1)
    end

    it "does not push to Redis directly" do
      Sidekiq::Testing.fake! do
        ExampleJob.perform_async("hello")
        expect(Sidekiq::Queues["default"]).to be_empty
      end
    end
  end

  describe "regular jobs without the extension" do
    it "does not stage to database" do
      expect {
        RegularJob.perform_async("hello")
      }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
    end
  end
end
