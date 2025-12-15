# frozen_string_literal: true

RSpec.describe Sidekiq::TransactionalJob do
  it "has a version number" do
    expect(Sidekiq::TransactionalJob::VERSION).not_to be nil
  end

  it "does something useful" do
    pending "add some examples"
    expect(false).to eq(true)
  end
end
