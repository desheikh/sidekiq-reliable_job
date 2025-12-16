# frozen_string_literal: true

FactoryBot.define do
  factory :outbox, class: "Sidekiq::ReliableJob::Outbox" do
    transient do
      queue { "default" }
    end

    sequence(:jid) { |_n| SecureRandom.hex(12) }
    job_class { "ExampleJob" }
    payload { { "class" => job_class, "args" => ["test message"], "queue" => queue, "jid" => jid } }
    status { "pending" }

    trait :enqueued do
      status { "enqueued" }
      enqueued_at { Time.current }
    end

    trait :dead do
      status { "dead" }
      enqueued_at { Time.current }
    end
  end
end
