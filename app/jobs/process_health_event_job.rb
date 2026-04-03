class ProcessHealthEventJob < ApplicationJob
  queue_as :maintenance

  def perform(health_event_id)
    health_event = HealthEvent.includes(:account, :service, :monitor, :monitor_source_binding).find_by(id: health_event_id)
    return if health_event.blank?

    Monitoring::HealthEventProcessor.new(health_event: health_event).call
  end
end
