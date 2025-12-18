# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::Client do
  describe ".push" do
    subject(:push) { described_class.push(item) }

    let(:item) do
      { "class" => "ExampleJob", "args" => ["test"], "queue" => "default" }
    end

    it "creates a staged job record" do
      expect { push }.to change(Sidekiq::ReliableJob::Outbox, :count).by(1)
    end

    it "returns a 24-character jid" do
      expect(push).to be_present
      expect(push.length).to eq(24)
    end

    it "stores the job with correct attributes" do
      jid = push
      record = Sidekiq::ReliableJob::Outbox.find_by(jid: jid)

      expect(record).to have_attributes(
        job_class: "ExampleJob",
        status: "pending",
        payload: include("queue" => "default", "args" => ["test"]),
      )
    end

    it "uses provided jid if present" do
      item["jid"] = "custom_jid_12345"

      expect(push).to eq("custom_jid_12345")
    end

    context "when transaction rolls back" do
      it "does not persist the staged job" do
        expect {
          ActiveRecord::Base.transaction do
            described_class.push(item)
            raise ActiveRecord::Rollback
          end
        }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
      end
    end

    context "when job with same JID already exists" do
      before { create(:outbox, jid: "existing_jid") }

      let(:item) { super().merge("jid" => "existing_jid") }

      it "raises an error" do
        expect { push }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context "with ActiveJob wrapper" do
      let(:item) do
        {
          "class" => wrapper_class,
          "wrapped" => "ExampleActiveJob",
          "args" => [{ "job_class" => "ExampleActiveJob", "arguments" => ["test"] }],
          "queue" => "default",
        }
      end

      context "with Sidekiq 8+ wrapper" do
        let(:wrapper_class) { "Sidekiq::ActiveJob::Wrapper" }

        it "extracts the wrapped job class" do
          jid = push
          record = Sidekiq::ReliableJob::Outbox.find_by(jid: jid)

          expect(record.job_class).to eq("ExampleActiveJob")
        end
      end

      context "with legacy adapter wrapper" do
        let(:wrapper_class) { "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper" }

        it "extracts the wrapped job class" do
          jid = push
          record = Sidekiq::ReliableJob::Outbox.find_by(jid: jid)

          expect(record.job_class).to eq("ExampleActiveJob")
        end
      end
    end
  end
end
