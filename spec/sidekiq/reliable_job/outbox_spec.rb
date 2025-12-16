# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::Outbox do
  describe "database constraints" do
    it "enforces NOT NULL on jid" do
      job = build(:outbox, jid: nil)
      expect { job.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "enforces unique jid" do
      existing = create(:outbox)
      duplicate = build(:outbox, jid: existing.jid)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces NOT NULL on job_class" do
      job = build(:outbox, job_class: nil)
      expect { job.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "enforces NOT NULL on status" do
      job = build(:outbox, status: nil)
      expect { job.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "scopes" do
    let!(:pending_job) { create(:outbox, status: "pending") }
    let!(:enqueued_job) { create(:outbox, :enqueued) }
    let!(:dead_job) { create(:outbox, :dead) }

    describe ".pending" do
      it "returns only pending jobs" do
        expect(described_class.pending).to contain_exactly(pending_job)
      end
    end

    describe ".enqueued" do
      it "returns only enqueued jobs" do
        expect(described_class.enqueued).to contain_exactly(enqueued_job)
      end
    end

    describe ".dead" do
      it "returns only dead jobs" do
        expect(described_class.dead).to contain_exactly(dead_job)
      end
    end
  end
end
