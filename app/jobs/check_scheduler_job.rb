class CheckSchedulerJob < ApplicationJob
  queue_as :scheduler

  BATCH_SIZE = 200

  def perform
    now = Time.current

    ServiceCheck.due(now).limit(BATCH_SIZE).find_each do |service_check|
      next unless service_check.acquire_lease!

      queue = service_check.interval_seconds == 30 ? :checks_fast : :checks_regular
      scheduled_at = now + rand(0.0..2.0)
      CheckExecutionJob.set(queue: queue).perform_later(service_check.id, scheduled_at: scheduled_at.iso8601)
    end
  end
end
