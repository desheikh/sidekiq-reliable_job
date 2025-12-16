# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::Client do
  subject(:client) { described_class.new }

  # Disable Sidekiq testing mode to test actual staging behavior
  around do |example|
    Sidekiq::Testing.disable! do
      example.run
    end
  end

  describe "#push" do
    let(:item) do
      {
        "class" => "ExampleJob",
        "args" => ["test message"],
        "queue" => "default",
      }
    end

    it "creates a staged job record" do
      expect { client.push(item) }.to change(Sidekiq::ReliableJob::Outbox, :count).by(1)
    end

    it "returns the jid" do
      jid = client.push(item)
      expect(jid).to be_present
      expect(jid.length).to eq(24) # hex(12) = 24 characters
    end

    it "stores the job payload" do
      jid = client.push(item)
      outbox_record = Sidekiq::ReliableJob::Outbox.find_by(jid: jid)

      expect(outbox_record.job_class).to eq("ExampleJob")
      expect(outbox_record.payload["queue"]).to eq("default")
      expect(outbox_record.payload["args"]).to eq(["test message"])
      expect(outbox_record.status).to eq("pending")
    end

    it "uses provided jid if present" do
      item["jid"] = "custom_jid_12345"
      jid = client.push(item)
      expect(jid).to eq("custom_jid_12345")
    end

    context "when transaction rolls back" do
      it "does not persist the staged job" do
        expect {
          ActiveRecord::Base.transaction do
            client.push(item)
            raise ActiveRecord::Rollback
          end
        }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
      end
    end
  end

  describe "#push_bulk" do
    it "delegates to the redis client" do
      items = { "class" => "ExampleJob", "args" => [["msg1"], ["msg2"]] }

      # push_bulk bypasses staging and goes directly to Redis
      expect { client.push_bulk(items) }.not_to change(Sidekiq::ReliableJob::Outbox, :count)
    end
  end
end
