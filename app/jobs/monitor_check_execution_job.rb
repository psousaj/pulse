class MonitorCheckExecutionJob < ApplicationJob
  queue_as :checks_regular

  def perform(monitor_id, scheduled_at: nil)
    monitor = PulseMonitor.includes(:account, :service).find_by(id: monitor_id)
    return if monitor.blank? || !monitor.enabled? || !monitor.internal_strategy?

    Monitoring::MonitorCheckExecutionService.new(monitor: monitor, scheduled_at: scheduled_at).call
  end
end
