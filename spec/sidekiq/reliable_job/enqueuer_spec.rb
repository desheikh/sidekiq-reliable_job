# frozen_string_literal: true

RSpec.describe Sidekiq::ReliableJob::Enqueuer do
  subject(:enqueuer) { described_class.new(config) }

  let(:config) { instance_double(Sidekiq::Config) }

  describe "#start" do
    after { enqueuer.stop }

    it "starts a background thread" do
      enqueuer.start
      sleep 0.05

      expect(enqueuer.instance_variable_get(:@thread)).to be_a(Thread)
    end
  end

  describe "#stop" do
    it "sets done flag to stop the processing loop" do
      enqueuer.stop

      expect(enqueuer.instance_variable_get(:@done)).to be true
    end
  end
end
