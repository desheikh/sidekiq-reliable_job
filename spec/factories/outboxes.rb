# frozen_string_literal: true

FactoryBot.define do
  factory :outbox, class: "Sidekiq::ReliableJob::Outbox" do
    transient do
      queue { "default" }
      scheduled_at { nil }
    end

    sequence(:jid) { |_n| SecureRandom.hex(12) }
    job_class { "ExampleJob" }
    payload do
      base = { "class" => job_class, "args" => ["test message"], "queue" => queue, "jid" => jid }
      scheduled_at ? base.merge("at" => scheduled_at.to_f) : base
    end
    status { "pending" }

    trait :enqueued do
      status { "enqueued" }
      enqueued_at { Time.current }
    end

    trait :scheduled do
      status { "scheduled" }
      enqueued_at { Time.current }
      scheduled_at { 1.hour.from_now }
    end

    trait :dead do
      status { "dead" }
      enqueued_at { Time.current }
    end
  end
end
