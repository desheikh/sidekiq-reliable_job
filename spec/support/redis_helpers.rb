# frozen_string_literal: true

module RedisHelpers
  def clear_redis_queues
    Sidekiq.redis do |conn|
      keys = conn.keys("queue:*")
      conn.del(*keys) if keys.any?
      conn.del("schedule")
    end
  end

  def redis_queue_size(queue)
    Sidekiq.redis { |conn| conn.llen("queue:#{queue}") }
  end

  def redis_queue_jobs(queue)
    Sidekiq.redis { |conn| conn.lrange("queue:#{queue}", 0, -1) }
  end

  def redis_schedule_size
    Sidekiq.redis { |conn| conn.zcard("schedule") }
  end

  def redis_schedule_jobs
    Sidekiq.redis { |conn| conn.call("ZRANGE", "schedule", "0", "-1", "WITHSCORES") }
  end
end
