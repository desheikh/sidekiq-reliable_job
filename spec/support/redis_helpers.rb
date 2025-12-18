# frozen_string_literal: true

module RedisHelpers
  def clear_redis_queues
    Sidekiq.redis do |conn|
      keys = conn.keys("queue:*")
      conn.del(*keys) if keys.any?
    end
  end

  def redis_queue_size(queue)
    Sidekiq.redis { |conn| conn.llen("queue:#{queue}") }
  end

  def redis_queue_jobs(queue)
    Sidekiq.redis { |conn| conn.lrange("queue:#{queue}", 0, -1) }
  end
end
