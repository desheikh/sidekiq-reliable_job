# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob do
  it "has a version number" do
    expect(Sidekiq::ReliableJob::VERSION).not_to be_nil
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(Sidekiq::ReliableJob::Configuration)
    end

    it "returns the same instance on multiple calls" do
      first_call = described_class.configuration
      second_call = described_class.configuration
      expect(first_call).to be(second_call)
    end

    it "has a base_class setting" do
      expect(described_class.configuration.base_class).to be_present
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      described_class.configure do |config|
        expect(config).to be(described_class.configuration)
      end
    end

    it "allows setting base_class" do
      original = described_class.configuration.base_class

      described_class.configure do |config|
        config.base_class = "CustomRecord"
      end

      expect(described_class.configuration.base_class).to eq("CustomRecord")

      # Reset to original
      described_class.configuration.base_class = original
    end
  end

  describe ".configure_client!" do
    it "registers the client middleware" do
      config = instance_double(Sidekiq::Config)
      chain = instance_double(Sidekiq::Middleware::Chain)

      allow(config).to receive(:client_middleware).and_yield(chain)
      allow(chain).to receive(:add)

      described_class.configure_client!(config)

      expect(chain).to have_received(:add).with(Sidekiq::ReliableJob::ClientMiddleware)
    end
  end

  describe ".configure_server!" do
    it "registers the server middleware" do
      config = instance_double(Sidekiq::Config)
      chain = instance_double(Sidekiq::Middleware::Chain)
      death_handlers = []

      allow(config).to receive(:client_middleware).and_yield(chain)
      allow(config).to receive(:server_middleware).and_yield(chain)
      allow(config).to receive(:on)
      allow(config).to receive(:death_handlers).and_return(death_handlers)
      allow(chain).to receive(:add)

      described_class.configure_server!(config)

      expect(chain).to have_received(:add).with(Sidekiq::ReliableJob::ServerMiddleware)
    end

    it "registers a death handler" do
      config = instance_double(Sidekiq::Config)
      chain = instance_double(Sidekiq::Middleware::Chain)
      death_handlers = []

      allow(config).to receive(:client_middleware).and_yield(chain)
      allow(config).to receive(:server_middleware).and_yield(chain)
      allow(config).to receive(:on)
      allow(config).to receive(:death_handlers).and_return(death_handlers)
      allow(chain).to receive(:add)

      described_class.configure_server!(config)

      expect(death_handlers.size).to eq(1)
    end

    it "also configures client middleware" do
      config = instance_double(Sidekiq::Config)
      chain = instance_double(Sidekiq::Middleware::Chain)
      death_handlers = []

      allow(config).to receive(:client_middleware).and_yield(chain)
      allow(config).to receive(:server_middleware).and_yield(chain)
      allow(config).to receive(:on)
      allow(config).to receive(:death_handlers).and_return(death_handlers)
      allow(chain).to receive(:add)

      described_class.configure_server!(config)

      expect(chain).to have_received(:add).with(Sidekiq::ReliableJob::ClientMiddleware)
    end
  end

  describe ".on_death" do
    let!(:outbox_record) { create(:outbox, :enqueued, jid: "dead_job_123") }

    context "when preserve_dead_jobs is false (default)" do
      it "deletes reliable jobs from outbox" do
        job = { "jid" => "dead_job_123", "reliable_job" => true }

        described_class.on_death(job, RuntimeError.new("failed"))

        expect(Sidekiq::ReliableJob::Outbox.exists?(jid: "dead_job_123")).to be false
      end
    end

    context "when preserve_dead_jobs is true" do
      before { described_class.configuration.preserve_dead_jobs = true }
      after { described_class.configuration.preserve_dead_jobs = false }

      it "marks reliable jobs as dead" do
        job = { "jid" => "dead_job_123", "reliable_job" => true }

        described_class.on_death(job, RuntimeError.new("failed"))

        expect(outbox_record.reload.status).to eq("dead")
      end
    end

    it "ignores non-reliable jobs" do
      job = { "jid" => "dead_job_123" }

      described_class.on_death(job, RuntimeError.new("failed"))

      expect(outbox_record.reload.status).to eq("enqueued")
    end
  end
end
