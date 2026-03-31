class NotificationDispatchJob < ApplicationJob
  queue_as :notifications

  def perform(incident_id, event_type)
    incident = Incident.includes(:service, :account).find_by(id: incident_id)
    return if incident.blank?

    Notifications::Dispatcher.new(incident:, event_type: event_type).call
  end
end
