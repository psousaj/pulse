class MonitorCheckSchedulerJob < ApplicationJob
  queue_as :scheduler

  BATCH_SIZE = 200

  def perform
    now = Time.current

    PulseMonitor.due(now).limit(BATCH_SIZE).find_each do |monitor|
      next unless monitor.acquire_lease!

      queue = monitor.interval_seconds.to_i <= 30 ? :checks_fast : :checks_regular
      scheduled_at = now + rand(0.0..2.0)
      MonitorCheckExecutionJob.set(queue: queue).perform_later(monitor.id, scheduled_at: scheduled_at.iso8601)
    end
  end
end
