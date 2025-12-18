# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe ".configuration" do
    subject(:configuration) { described_class.configuration }

    it { is_expected.to be_a(described_class::Configuration) }
    it { is_expected.to have_attributes(base_class: be_present) }

    it "returns the same instance on multiple calls" do
      expect(configuration).to be(described_class.configuration)
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

      described_class.configure { |c| c.base_class = "CustomRecord" }
      expect(described_class.configuration.base_class).to eq("CustomRecord")

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

      expect(chain).to have_received(:add).with(described_class::ClientMiddleware)
    end
  end

  describe ".configure_server!" do
    let(:config) { instance_double(Sidekiq::Config) }
    let(:chain) { instance_double(Sidekiq::Middleware::Chain) }
    let(:death_handlers) { [] }

    before do
      allow(config).to receive_messages(
        client_middleware: nil,
        server_middleware: nil,
        on: nil,
        death_handlers: death_handlers,
      )
      allow(config).to receive(:client_middleware).and_yield(chain)
      allow(config).to receive(:server_middleware).and_yield(chain)
      allow(chain).to receive(:add)
    end

    it "registers both client and server middleware" do
      described_class.configure_server!(config)

      expect(chain).to have_received(:add).with(described_class::ClientMiddleware)
      expect(chain).to have_received(:add).with(described_class::ServerMiddleware)
    end

    it "registers a death handler" do
      described_class.configure_server!(config)

      expect(death_handlers.size).to eq(1)
    end
  end

  describe ".on_death" do
    let!(:outbox_record) { create(:outbox, :enqueued, jid: "dead_job_123") }
    let(:job) { { "jid" => "dead_job_123", "reliable_job" => true } }
    let(:exception) { RuntimeError.new("failed") }

    it "ignores non-reliable jobs" do
      described_class.on_death({ "jid" => "dead_job_123" }, exception)

      expect(outbox_record.reload.status).to eq("enqueued")
    end

    context "when preserve_dead_jobs is false (default)" do
      it "deletes the job from outbox" do
        described_class.on_death(job, exception)

        expect(described_class::Outbox.exists?(jid: "dead_job_123")).to be false
      end
    end

    context "when preserve_dead_jobs is true" do
      around do |example|
        described_class.configuration.preserve_dead_jobs = true
        example.run
        described_class.configuration.preserve_dead_jobs = false
      end

      it "marks the job as dead" do
        described_class.on_death(job, exception)

        expect(outbox_record.reload.status).to eq("dead")
      end
    end
  end
end
